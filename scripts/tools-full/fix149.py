import pathlib
p = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = p.read_text(encoding="utf-8")
old = '  Say (L"  [MENU149] console stays on, GUI skipped");\n  Usb149LateDiag ();'
new = ('  Say (L"  [MENU149] console stays on, GUI skipped");\n'
       '  {\n'
       '    STATIC UINTN  mGuiDisabled149 = 0;\n'
       '\n'
       '    if (mGuiDisabled149 == 0) {\n'
       '      Usb149LateDiag ();\n'
       '    } else {\n'
       '      RunMenu ();\n'
       '    }\n'
       '  }\n')
assert old in s, "anchor missing"
s = s.replace(old, new)
p.write_text(s, encoding="utf-8")
print("ok, RunMenu referenced:", "RunMenu ();" in s)