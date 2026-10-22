set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys121' in s:
    print('already'); raise SystemExit
old = '''          // keys119: any non-navigation key (power button / others) = confirm
          if (PendingAct != Selected) {
            PendingAct   = Selected + 1;   // store +1 so 0 means "none"
            ConfirmTicks = 0;
            Redraw       = TRUE;
          } else {'''
new = '''          // keys121: safe items act immediately; dangerous ones need a 2nd press
          if (Selected != 3 && Selected != 4) {
            PendingAct = 0;
            Status     = EFI_SUCCESS;
            goto do_action;
          }
          if (PendingAct != Selected + 1) {
            PendingAct   = Selected + 1;
            ConfirmTicks = 0;
            Redraw       = TRUE;
          } else {
           do_action:'''
if old not in s:
    print('anchor not found'); raise SystemExit(2)
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('keys121 applied')
PY
grep -n "keys121\|do_action" "$F" | head -6