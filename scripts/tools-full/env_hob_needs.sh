#!/bin/bash
set -e
ENV=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.efi
PP=/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
echo "=== which Qualcomm HOB GUIDs does EnvDxe.efi embed? ==="
python3 - "$ENV" <<'PY'
import sys, uuid
blob = open(sys.argv[1], 'rb').read()
guids = {
 "InfoBlk":        "90A49AFD-422F-08AE-9611-E788D3804845",
 "Shim":           "BEDAEABC-5E70-4D66-9733-213D072B9D04",
 "Prodmode":       "D5F8D706-D602-4F39-969D-A04FE2BB7F61",
 "SchedulerIface": "8EC2BD8D-56D7-49EF-8796-6317BF0EBF8",
 "FvList":         "12DBD93D-402A-416E-EC20-5F80CF5F7FE7",
 "DtbExtension":  "3A06E1E8-61F6-11EB-BBED-4B476E2FF6A7",
 "DtbExtnProto":   "0389B776-625F-11EB-83BE-C741A913DE34",
}
for name, g in guids.items():
    u = uuid.UUID(g)
    le = u.bytes_le
    hits = []
    i = blob.find(le)
    while i >= 0 and len(hits) < 4:
        hits.append(hex(i)); i = blob.find(le, i+1)
    print(f"  {name:15s} {g}  -> {hits or 'NOT FOUND'}")
PY
echo
echo "=== PlatformPei.c BuildXblHobs (lines 88..135) ==="
sed -n '88,135p' "$PP"
