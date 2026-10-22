import pathlib, sys
PKG = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg')
APR = PKG / 'Include' / 'APRIORI.inc'
DSC = PKG / 'vermeer.dsc'
INF_LINE = '  INF Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf\n'
COMP_LINE = '  Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf\n'
a = APR.read_text(encoding='utf-8')
# drop any existing SimpleFb line, then append at EOF (same place MenuDxe works from)
a = ''.join(l for l in a.splitlines(True) if 'SimpleFbDxe.inf' not in l)
if not a.endswith('\n'):
    a += '\n'
a += INF_LINE
APR.write_text(a, encoding='utf-8')
s = DSC.read_text(encoding='utf-8')
if 'SimpleFbDxe.inf' not in s:
    i = s.find('[Components]')
    eol = s.find('\n', i) + 1
    s = s[:eol] + COMP_LINE + s[eol:]
    DSC.write_text(s, encoding='utf-8')
print('appended SimpleFbDxe at EOF; dsc ok =', 'SimpleFbDxe.inf' in DSC.read_text(encoding='utf-8'))