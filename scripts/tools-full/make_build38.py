import pathlib

d = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl')
src = (d / 'build_keys37.sh').read_text()
s = src.replace('keys37', 'keys38')

# replace the "remove the override" step by an explicit NULL mapping in vermeer.dsc (last wins)
old_start = s.index('python3 - "$PKG" <<\'PYX\'')
old_end = s.index('PYX\n', old_start) + len('PYX\n')
new = '''python3 - "$PKG" <<'PYX'
import pathlib, sys
dsc = pathlib.Path(sys.argv[1]) / "vermeer.dsc"
text = dsc.read_text(encoding="utf-8")
lines = [l for l in text.splitlines() if "PlatformPeiLib|" not in l]
NULLMAP = "  PlatformPeiLib|SiliciumNullPkg/Library/PlatformPeiLibNull/PlatformPeiLibNull.inf"
anchor = "  ConfigurationMapLib|vermeerPkg/Library/ConfigurationMapLib/ConfigurationMapLib.inf"
out = []
done = False
for line in lines:
    out.append(line)
    if not done and line.strip() == anchor.strip():
        out.append(NULLMAP)
        done = True
if not done:
    raise SystemExit("ConfigurationMapLib anchor missing in vermeer.dsc")
dsc.write_text("\\n".join(out) + "\\n", encoding="utf-8")
print("dsc: PlatformPeiLib forced to NULL:", done)
PYX
'''
s = s[:old_start] + new + s[old_end:]

# probe anchor back to PcdDxe (second dispatch, before EnvDxe)
s = s.replace('"RscDxe/RscDxe.inf" in line', '"MdeModulePkg/Universal/PCD/Dxe/Pcd.inf" in line')

s = s.replace('# keys37 = keys25 lineage but PlatformPeiLib stays NULL (no DTBExtn HOB -> EnvDxe cannot\n'
              '#          dereference the bogus interface) + probe dispatched last, UI demo only.',
              '# keys38 = keys37 lineage, PlatformPeiLib explicitly NULL (no DTB Extension HOB at all),\n'
              '#          probe dispatched second, interactive UI armed as a 5 s one-shot timer.')

out = d / 'build_keys38.sh'
out.write_text(s)
print('wrote', out)
