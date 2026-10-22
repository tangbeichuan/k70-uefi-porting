#!/bin/bash
set -e
cp /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.efi /tmp/EnvDxe.efi
python3 - <<'PY'
import uuid
blob = open('/tmp/EnvDxe.efi','rb').read()
g = {
 "InfoBlk":        "90A49AFD-422F-08AE-9611-E788D3804845",
 "Shim":           "BEDAEABC-5E70-4D66-9733-213D072B9D04",
 "Prodmode":       "D5F8D706-D602-4F39-969D-A04FE2BB7F61",
 "SchedulerIface": "8EC2BD8D-56D7-49EF-8796-631778F8EBF8",
 "FvList":         "12DBD93D-402A-416E-EC20-5F80CF5F7FE7",
 "DtbExtension":   "3A06E1E8-61F6-11EB-BBED-4B476E2FF6A7",
 "DtbExtnProto":   "0389B776-625F-11EB-83BE-C741A913DE34",
}
for name, s in g.items():
    le = uuid.UUID(s).bytes_le
    hits, i = [], blob.find(le)
    while i >= 0 and len(hits) < 3:
        hits.append(hex(i)); i = blob.find(le, i+1)
    print(f"  {name:15s} {s}  -> {hits or 'NOT FOUND'}")
PY
