#!/usr/bin/env bash
# keys47 = keys44 (显示 + 音量键 + 菜单，真机验证通过) + 我们自己写的 DTBExtn provider
#
# 目标：把 UFSDxe 放回来，让它能在派发时 LocateProtocol(DTBExtn) 成功，从而真正初始化 UFS。
#
# 关键事实（逆向所得，详见 D:\本地项目-01\K70-UEFI-build\DTBExtn-接口逆向.md）：
#   - 协议 GUID = 0389B776-625F-11EB-83BE-C741A913DE34
#   - 接口是 0x108 字节函数指针表：+0x30 GetNode / +0x58 GetProp / +0xa8 GetProp / +0xc8 GetPropByte
#   - UFSDxe 需要的树内容全部在 xbl_config 分区的 cb20 树里（/soc/ufs0@1D80000）
#   - PEI 里的 DTB Extension HOB 一律不碰（keys33-46 的崩溃全部源于此）
set -e -o pipefail

TAG=${1:-keys84}
UEFI=/root/k70/uefi
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg
TOOLS=/mnt/d/本地项目-01/_k70port_extract
FD_OUT=$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd
DTB_SRC="/mnt/d/_k70tmp/xbl_ufs_57.dtb"

cd "$UEFI"

cp "$PKG/vermeer.dsc"             /tmp/vermeer.dsc.bak
cp "$PKG/vermeer.fdf"             /tmp/vermeer.fdf.bak
cp "$PKG/Include/DXE.inc"         /tmp/DXE.inc.bak
cp "$PKG/Include/APRIORI.inc"     /tmp/APRIORI.inc.bak
restore() {
  cp /tmp/vermeer.dsc.bak         "$PKG/vermeer.dsc"
  cp /tmp/vermeer.fdf.bak         "$PKG/vermeer.fdf"
  cp /tmp/DXE.inc.bak             "$PKG/Include/DXE.inc"
  cp /tmp/APRIORI.inc.bak         "$PKG/Include/APRIORI.inc"
}
trap restore EXIT

# ---- 1) 驱动源码 ----------------------------------------------------------------
for d in VermeerKeyProbeDxe VermeerDtDumpDxe VermeerDtbExtnDxe; do
  mkdir -p "$PKG/Drivers/$d"
  cp "$TOOLS/port-drivers/$d/$d.c"   "$PKG/Drivers/$d/"
  cp "$TOOLS/port-drivers/$d/$d.inf" "$PKG/Drivers/$d/"
done

# ---- 2) 设备树 blob 进 FV（RAW FFS 文件，GUID 与驱动里的 mDtbFileGuid 一致）-----
mkdir -p "$PKG/FdtBlob"
if [ ! -f "$PKG/FdtBlob/xbl_ufs.dtb" ] || ! cmp -s "$DTB_SRC" "$PKG/FdtBlob/xbl_ufs.dtb"; then
  cp "$DTB_SRC" "$PKG/FdtBlob/xbl_ufs.dtb"
fi
echo "dtb blob: $(ls -l "$PKG/FdtBlob/xbl_ufs.dtb" | awk '{print $5}') bytes"

python3 "$TOOLS/wsl/gates.py" keyprobe    "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
python3 "$TOOLS/wsl/gates.py" vendorinput "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
python3 "$TOOLS/wsl/gates.py" set "$PKG/vermeer.dsc" VERMEER_KEYPROBE 1

python3 - "$PKG" <<'PY'
import pathlib, sys

pkg    = pathlib.Path(sys.argv[1])
EXTN   = "vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.inf"
DUMP   = "vermeerPkg/Drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.inf"
FREEF  = "7E5B1C3A-9D24-4E77-9C1B-2A6D5F8E4C31"
DTBPATH = "vermeerPkg/FdtBlob/xbl_ufs.dtb"

# ---- a) dsc: [Components] 里注册 provider（挂在 KeyProbe 后面）----
dsc  = pkg / "vermeer.dsc"
text = dsc.read_text(encoding="utf-8")
if EXTN not in text:
    lines, done = [], False
    for line in text.splitlines(keepends=True):
        lines.append(line)
        if (not done) and "VermeerKeyProbeDxe.inf" in line and not line.strip().startswith("#"):
            lines.append("  " + EXTN + "\n")
            done = True
    text = "".join(lines)
    dsc.write_text(text, encoding="utf-8")
    print("dsc: provider registered:", done)
else:
    print("dsc: provider already registered")

# ---- b) fdf: INF 行 + DTB 的 RAW FFS 文件 ----
fdf  = pkg / "vermeer.fdf"
text = fdf.read_text(encoding="utf-8")
if EXTN not in text:
    lines, done = [], False
    for line in text.splitlines(keepends=True):
        low = line.lower()
        if (not done) and low.lstrip().startswith("inf") and "vermeerkeyprobedxe.inf" in low:
            lines.append(line)
            lines.append("  INF " + EXTN + "\n")
            done = True
            continue
        lines.append(line)
    text = "".join(lines)
    print("fdf: provider INF inserted:", done)
else:
    print("fdf: provider INF already present")

#
# 注意：FILE 块必须位于某个 [FV...] 段内部，直接追加到文件末尾会落在 [FD] 段之后，
# GenFds 会报 "expected [FD.] near line ... }"。所以紧跟 provider 的 INF 行插入。
#
if FREEF not in text.upper():
    block = (
        "\n"
        "FILE FREEFORM = " + FREEF + " {\n"
        "  SECTION RAW = " + DTBPATH + "\n"
        "}\n"
    )
    lines, done = [], False
    for line in text.splitlines(keepends=True):
        lines.append(line)
        if (not done) and EXTN in line and line.lower().lstrip().startswith("inf"):
            lines.append(block)
            done = True
    text = "".join(lines)
    print("fdf: device-tree RAW file inserted inside FV:", done)
else:
    print("fdf: device-tree RAW file already present")
fdf.write_text(text, encoding="utf-8")

# ---- c) APRIORI：provider 紧跟 PcdDxe 派发（远早于 UFSDxe 的第 93 行）----
ap = pkg / "Include" / "APRIORI.inc"
text = ap.read_text(encoding="utf-8")
if EXTN not in text:
    lines, done = [], False
    for line in text.splitlines(keepends=True):
        lines.append(line)
        if (not done) and "MdeModulePkg/Universal/PCD/Dxe/Pcd.inf" in line:
            lines.append("  INF " + EXTN + "\n")
            done = True
    ap.write_text("".join(lines), encoding="utf-8")
    print("apriori: provider inserted after Pcd:", done)
else:
    print("apriori: provider already present")
PY

# ---- 3) vendor 集合 = keys14 去掉 ufsdxe 的删除项（即 UFSDxe 这次保留）----------
python3 - "$PKG" <<'PY'
import re, sys, pathlib

pkg = pathlib.Path(sys.argv[1])

DROP = [
    "usbfndwc3", "usbdevicedxe", "pildxe", "pilproxy", "spss", "tzdxe", "charger", "chg",
    "sdcc", "featureenabler", "ddrinfo", "limitsdxe", "gpipdxe", "gpidexe", "ucdxe",
    "rngdxe", "tsens", "clockdxe", "displaydxe", "rammanagerdxe",
    "keys84_keep_pmicdxe",   # keys84: PmicDxe 请回来（USB VBUS 需要 PMIC version 协议）: 绕开 PmicDxe 这个墙（0xa0 名字查询把它打崩）
    "halionmu",  # keys69: HALIOMMU 要的是 ACPI IORT 表，不是 DT，必然失败后跳 0
]

dsc = pkg / "vermeer.dsc"
s = dsc.read_text(encoding="utf-8")
s = re.sub(r"^( *VERMEER_VENDOR_HW *= *)\d+", r"\g<1>1", s, count=1, flags=re.M)
s = re.sub(r"^( *VERMEER_VENDOR_INPUT *= *)\d+", r"\g<1>0", s, count=1, flags=re.M)
dsc.write_text(s, encoding="utf-8")

kept, dropped = set(), 0
for name in ("vermeer.dsc", "vermeer.fdf", "Include/DXE.inc", "Include/APRIORI.inc"):
    p = pkg / name
    if not p.exists():
        continue
    out = []
    for line in p.read_text(encoding="utf-8").splitlines(keepends=True):
        # 先还原上一轮我们自己加的注释，保证本轮 DROP 列表真的生效
        if line.startswith("# [keys47-drop] "):
            line = line[len("# [keys47-drop] "):]
        elif line.startswith("# [keys70-hard] "):
            line = line[len("# [keys70-hard] "):]
        low = line.lower()
        if low.lstrip().startswith("inf") and "binaries/vermeer" in low:
            if any(token in low for token in DROP):
                out.append("# [keys47-drop] " + line)
                dropped += 1
                continue
            kept.add(line.strip())
        out.append(line)
    p.write_text("".join(out), encoding="utf-8")

print("kept vendor modules:", len(kept), " dropped lines:", dropped)
print("UFSDxe kept:", any("UFSDxe" in k for k in kept))
PY

# ---- 3b) 硬编码剔除 HALIOMMU + UFSDxe（本次直接用自研直读驱动） ------------
python3 - "$PKG" <<'PY2'
import sys, pathlib
pkg = pathlib.Path(sys.argv[1]); n = 0
for name in ("vermeer.dsc", "vermeer.fdf", "Include/DXE.inc", "Include/APRIORI.inc"):
    p = pkg / name
    if not p.exists():
        continue
    out = []
    for line in p.read_text(encoding="utf-8").splitlines(keepends=True):
        if ("HALIOMMUDxe" in line) and not line.lstrip().startswith("#"):
            out.append("# [keys70-hard] " + line); n += 1
        else:
            out.append(line)
    p.write_text("".join(out), encoding="utf-8")
print("hard-dropped HALIOMMU lines:", n)
PY2

python3 /mnt/d/本地项目-01/_tools/patch_ufsmap84.py "$PKG"

# ---- 4) 编译 + 打包 -------------------------------------------------------------
source /root/k70/venv/bin/activate
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -8

FD=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
[ -f "$FD" ] || { echo "build produced no FD"; exit 1; }
cp "$FD" "$FD_OUT"
cp "$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref" "/tmp/guid-$TAG.xref"
echo "=== $TAG FD ==="; ls -l "$FD_OUT"; sha256sum "$FD_OUT"
echo "--- provider / UFSDxe / probe in FV? ---"
grep -iE 'VermeerDtbExtnDxe|VermeerKeyProbeDxe|UFSDxe|EnvDxe' "/tmp/guid-$TAG.xref" || echo "  none found"
echo "--- FVMAIN 里有那棵树的 RAW 文件吗 ---"
grep -i "7E5B1C3A" "$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt" 2>/dev/null || \
  find "$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV" -name '*.Fv.txt' -exec grep -li '7E5B1C3A' {} + 2>/dev/null || \
  echo "  (Fv.txt not found, will verify after boot)"



