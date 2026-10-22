#!/usr/bin/env python3
# patch_fb107.py - register SimpleFbDxe (GOP) into vermeer.dsc + APRIORI.inc
import pathlib
import sys

PKG = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg')
DSC = PKG / 'vermeer.dsc'
APR = PKG / 'Include' / 'APRIORI.inc'

INF_LINE = '  INF Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf\n'
COMP_LINE = '  Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf\n'
ANCHOR = '  INF MdeModulePkg/Universal/Console/ConSplitterDxe/ConSplitterDxe.inf\n'

# --- 1) dsc [Components] ---
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

# --- 2) APRIORI.inc (before ConSplitterDxe) ---
a = APR.read_text(encoding='utf-8')
if 'SimpleFbDxe.inf' not in a:
    if ANCHOR not in a:
        print('ERROR: APRIORI anchor (ConSplitterDxe) not found')
        sys.exit(1)
    a = a.replace(ANCHOR, INF_LINE + ANCHOR, 1)
    APR.write_text(a, encoding='utf-8')
    print('apriori: inserted SimpleFbDxe before ConSplitterDxe -> True')
else:
    print('apriori: SimpleFbDxe already present')

# --- 3) sanity: PCDs ---
d = DSC.read_text(encoding='utf-8')
for k in ('PcdFrameBufferWidth|1440', 'PcdFrameBufferHeight|3200', 'PcdFrameBufferColorDepth|32'):
    print('pcd %s -> %s' % (k, k in d))
