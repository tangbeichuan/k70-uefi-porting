import pathlib

d = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl')
src = (d / 'build_keys25.sh').read_text()
s = src.replace('keys25', 'keys37')

ins = """python3 - "$PKG" <<'PYX'
import pathlib, sys
dsc = pathlib.Path(sys.argv[1]) / "vermeer.dsc"
orig = dsc.read_text(encoding="utf-8")
keep = [l for l in orig.splitlines() if "PlatformPeiLib|QcomPkg/Library/PlatformPeiLib/PlatformPeiLib.inf" not in l]
new = "\\n".join(keep) + "\\n"
dsc.write_text(new, encoding="utf-8")
print("dsc: PlatformPeiLib back to NULL :", orig != new)
PYX

"""

marker = 'export DROP_JSON='
i = s.index(marker)
s = s[:i] + ins + s[i:]

# note in the header
s = s.replace('# keys37 = keys24 + probe dispatched at END of APRIORI.',
              '# keys37 = keys25 lineage but PlatformPeiLib stays NULL (no DTBExtn HOB -> EnvDxe cannot\n'
              '#          dereference the bogus interface) + probe dispatched last, UI demo only.')

out = d / 'build_keys37.sh'
out.write_text(s)
print('wrote', out)
