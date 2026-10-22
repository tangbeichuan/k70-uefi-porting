set +e
P=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe/DEBUG/VermeerDtbExtnDxe.efi
ls -l "$P" 2>/dev/null | cat
python3 - "$P" <<'PY'
import sys
try:
    d=open(sys.argv[1],'rb').read()
    # quick heuristic: look for our debug strings
    for s in (b'slot 0xa0', b'slot 0x40', b'vermeer dtb-extn provider'):
        print(s.decode(), d.find(s))
except Exception as e:
    print('err', e)
PY