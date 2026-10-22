#!/usr/bin/env python3
# patch_fb109.py - put SimpleFbDxe (GOP) into the FV at a location that is NOT
# inside a [!if USE_CUSTOM_DISPLAY_DRIVER] block, and make sure it is compiled.
import pathlib
import sys

PKG = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg')
DSC = PKG / 'vermeer.dsc'
APR = PKG / 'Include' / 'APRIORI.inc'

INF_LINE = '  INF Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf\n'
COMP_LINE = '  Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf\n'
ANCHOR = '  INF EmbeddedPkg/SimpleTextInOutSerial/SimpleTextInOutSerial.inf\n'

# --- 1) remove any earlier (wrongly placed) insertion -------------------
a = APR.read_text(encoding='utf-8')
if INF_LINE in a:
    a = a.replace(INF_LINE, '', 1)
    print('apriori: removed previous misplaced SimpleFbDxe line')

# --- 2) insert right after SimpleTextInOutSerial (unconditional region) --
if 'SimpleFbDxe.inf' not in a:
    if ANCHOR not in a:
        print('ERROR: APRIORI anchor (SimpleTextInOutSerial) not found')
        sys.exit(1)
    a = a.replace(ANCHOR, ANCHOR + INF_LINE, 1)
    print('apriori: inserted SimpleFbDxe after SimpleTextInOutSerial -> True')
APR.write_text(a, encoding='utf-8')

# --- 3) dsc [Components] ------------------------------------------------
s = DSC.read_text(encoding='utf-8')
if 'SimpleFbDxe.inf' not in s:
    idx = s.find('[Components]')
    if idx < 0:
        print('ERROR: no [Components] in dsc')
        sys.exit(1)
    eol = s.find('\n', idx) + 1
    s = s[:eol] + COMP_LINE + s[eol:]
    DSC.write_text(s, encoding='utf-8')
    print('dsc: added SimpleFbDxe -> True')
else:
    print('dsc: SimpleFbDxe already present')

# --- 4) report placement for the log -----------------------------------
a = APR.read_text(encoding='utf-8').splitlines()
for i, ln in enumerate(a, 1):
    if 'SimpleFbDxe' in ln:
        print('apriori line %d: %s' % (i, ln.strip()))
