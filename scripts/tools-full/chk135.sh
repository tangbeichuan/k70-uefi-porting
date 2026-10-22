set +e
E=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerDtbExtnDxe.efi
sha256sum "$E" | cat
python3 - "$E" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
# our 512 edit changes nothing textual; print a few code bytes around SlotGetGeneric calls is hard.
print("size", len(d), "crc-ish", sum(d) & 0xffffffff)
PY
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
ls -l --time-style=+%H:%M:%S "$FV" 2>/dev/null | cat
grep -c 'VermeerDtbExtnDxe' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref 2>/dev/null