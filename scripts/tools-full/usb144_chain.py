#!/usr/bin/env python3
"""keys144 pre-analysis: USB device-mode dispatch chain.

For UsbConfigDxe / UsbInitDxe / UsbfnDwc3Dxe / UsbDeviceDxe / UsbMsdDxe / UsbPwrCtrlDxe:
  * decode EFI_DEPEX (which protocol GUIDs must be present before dispatch)
  * resolve each GUID to a name via .dec files
  * find which FV modules contain each GUID (candidate producers/consumers)
  * check HAL IOMMU (54B6D3B4), E722B03F, DTBExtn (0389B776), SPMI (FA5F306B)
"""
import glob
import os
import re
import struct
import sys

UEFI = "/root/k70/uefi"
BIN = UEFI + "/Binaries/vermeer/QcomPkg/Drivers"
FVD = UEFI + "/Build/vermeerPkg/DEBUG_CLANGPDB/FV"
FVMAIN_INF = FVD + "/FVMAIN.inf"

MODULES = {
    "UsbConfigDxe": BIN + "/UsbConfigDxe/UsbConfigDxe.patched.efi",
    "UsbInitDxe": BIN + "/UsbInitDxe/UsbInitDxe.efi",
    "UsbfnDwc3Dxe": BIN + "/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi",
    "UsbDeviceDxe": BIN + "/UsbDeviceDxe/UsbDeviceDxe.efi",
    "UsbMsdDxe": BIN + "/UsbMsdDxe/UsbMsdDxe.patched.efi",
    "UsbPwrCtrlDxe": BIN + "/UsbPwrCtrlDxe/UsbPwrCtrlDxe.efi",
    "UsbBusDxe": BIN + "/UsbBusDxe/UsbBusDxe.efi",
}
DEPEX = {
    "UsbConfigDxe": BIN + "/UsbConfigDxe/UsbConfigDxe.depex",
    "UsbInitDxe": BIN + "/UsbInitDxe/UsbInitDxe.depex",
    "UsbfnDwc3Dxe": BIN + "/UsbfnDwc3Dxe/UsbfnDwc3Dxe.depex",
    "UsbDeviceDxe": BIN + "/UsbDeviceDxe/UsbDeviceDxe.depex",
    "UsbMsdDxe": BIN + "/UsbMsdDxe/UsbMsdDxe.depex",
    "UsbPwrCtrlDxe": BIN + "/UsbPwrCtrlDxe/UsbPwrCtrlDxe.depex",
}
SPECIAL = {
    "HAL_IOMMU": "54B6D3B4-5D33-4F91-8600-6C41D5DEB19A",
    "UsbConfig(E722B03F)": "E722B03F-B250-42CE-8EBD-5BD51812D037",
    "DTBExtn": "0389B776-625F-11EB-83BE-C741A913DE34",
    "SPMI(FA5F306B)": "FA5F306B-F47D-4AC4-A47D-882F8204EC30",
    "SHM_SMEM(F4E5C7D0)": "F4E5C7D0-D239-47CB-AACD-7F66EF763238",
    "ChipInfo(B0760469)": "B0760469-970C-487A-A4B5-28DB7B45CEF1",
    "PlatformInfo(157A5C45)": "157A5C45-21B2-43C5-BA7C-822FEE5FE599",
    "AcpiSDT(EB97088E)": "EB97088E-CFDF-49C6-BE4B-D906A5B20E86",
}


def gbytes(s):
    p = s.split("-")
    return struct.pack("<IHH", int(p[0], 16), int(p[1], 16), int(p[2], 16)) + bytes.fromhex("".join(p[3:]))


def gstr(b):
    a, bb, c = struct.unpack("<IHH", b[:8])
    return "%08X-%04X-%04X-%s-%s" % (a, bb, c, b[8:10].hex().upper(), b[10:16].hex().upper())


# ---- GUID name map from .dec files -----------------------------------------
LINE = re.compile(
    r"^\s*(\w+)\s*=\s*\{?\s*0x([0-9a-fA-F]{8})\s*,\s*0x([0-9a-fA-F]{4})\s*,\s*0x([0-9a-fA-F]{4})\s*,\s*"
    r"\{?\s*0x([0-9a-fA-F]{2})\s*,\s*0x([0-9a-fA-F]{2})\s*,\s*0x([0-9a-fA-F]{2})\s*,\s*"
    r"0x([0-9a-fA-F]{2})\s*,\s*0x([0-9a-fA-F]{2})\s*,\s*0x([0-9a-fA-F]{2})\s*,\s*"
    r"0x([0-9a-fA-F]{2})\s*,\s*0x([0-9a-fA-F]{2})")


def load_names():
    names = {}
    for root in (UEFI + "/Mu_Basecore", UEFI + "/Silicon", UEFI + "/QcomPkg", UEFI + "/Platforms"):
        for dp, dn, fn in os.walk(root):
            if "/Build" in dp:
                continue
            for f in fn:
                if not (f.endswith(".dec") or f.endswith(".inc") or f.endswith(".dsc.inc")):
                    continue
                try:
                    for line in open(os.path.join(dp, f), errors="ignore"):
                        m = LINE.match(line)
                        if not m:
                            continue
                        s = "%s-%s-%s-%s-%s" % (m.group(2), m.group(3), m.group(4),
                                                (m.group(5) + m.group(6)).upper(),
                                                "".join(m.group(i) for i in range(7, 13)).upper())
                        names.setdefault(s.upper(), m.group(1))
                except Exception:
                    pass
    return names


# ---- depex decoder ----------------------------------------------------------
def decode_depex(path):
    data = open(path, "rb").read()
    i = 0
    out = []      # list of GUID strings in evaluation order
    ops = []
    while i < len(data):
        op = data[i]
        i += 1
        if op == 0x00:
            ops.append("BEFORE")
        elif op == 0x01:
            ops.append("AFTER")
        elif op == 0x02:
            out.append(gstr(data[i:i + 16]))
            ops.append("PUSH")
            i += 16
        elif op == 0x03:
            ops.append("AND")
        elif op == 0x04:
            ops.append("OR")
        elif op == 0x05:
            ops.append("NOT")
        elif op == 0x06:
            ops.append("TRUE")
        elif op == 0x07:
            ops.append("FALSE")
        elif op == 0x08:
            ops.append("END")
            break
        else:
            ops.append("?0x%02x" % op)
    return out, ops


def main():
    names = load_names()
    print("=== A. depex of each USB driver (dispatch gate) ===")
    depex_guids = {}
    for mod, path in DEPEX.items():
        if not os.path.exists(path):
            print("  %-14s depex MISSING %s" % (mod, path))
            continue
        guids, ops = decode_depex(path)
        depex_guids[mod] = guids
        print("  %-14s %d protocol(s)  ops=%s" % (mod, len(guids), " ".join(ops)))
        for g in guids:
            print("        %s  %s" % (g, names.get(g.upper(), "UNKNOWN")))

    print()
    print("=== B. special GUIDs: dep / present in each module binary ===")
    hdr = "  %-14s" % "module"
    for k in SPECIAL:
        hdr += " %-20s" % k
    print(hdr)
    for mod, path in MODULES.items():
        if not os.path.exists(path):
            print("  %-14s MISSING BINARY" % mod)
            continue
        data = open(path, "rb").read()
        row = "  %-14s" % mod
        for k, gs in SPECIAL.items():
            pat = gbytes(gs)
            row += " %-20s" % ("YES" if pat in data else "-")
        print(row)

    print()
    print("=== C. FV modules that contain each depex GUID (candidate producer/consumer) ===")
    fv_files = []
    if os.path.exists(FVMAIN_INF):
        fv_files = re.findall(r"EFI_FILE_NAME = (\S+)", open(FVMAIN_INF).read())
    fv_map = {}
    for f in fv_files:
        try:
            info = open(f, "rb").read(), os.path.basename(os.path.dirname(f))
        except Exception:
            continue
        fv_map[info[1]] = info[0]
    all_depex = set()
    for gs in depex_guids.values():
        all_depex.update(gs)
    for g in sorted(all_depex):
        pat = gbytes(g)
        holders = [m for m, b in fv_map.items() if pat in b]
        print("  %s  %-46s -> %s" % (g, names.get(g.upper(), "UNKNOWN"), ", ".join(sorted(holders)) or "NONE IN FV"))

    print()
    print("=== D. FV producers for the protocols our drivers actually need ===")
    for k in ("SPMI(FA5F306B)", "SHM_SMEM(F4E5C7D0)", "ChipInfo(B0760469)",
              "PlatformInfo(157A5C45)", "AcpiSDT(EB97088E)", "HAL_IOMMU"):
        pat = gbytes(SPECIAL[k])
        holders = [m for m, b in fv_map.items() if pat in b]
        print("  %-22s -> %s" % (k, ", ".join(sorted(holders)) or "NONE IN FV"))


if __name__ == "__main__":
    main()
