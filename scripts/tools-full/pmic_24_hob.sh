#!/bin/bash
echo '--- files'
ls -la /root/k70/rt /root/k70/containers /root/k70/qemu-fw 2>/dev/null
python3 - <<'EOF'
import glob, os
# gEfiDtbExtensionHobGuid = 3a06e1e8-f661-11eb-bbed-4b476e2ff6a7
g = bytes.fromhex('e8e1063a'+'f661'+'eb11'+'bbed4b476e2ff6a7')
files = []
for pat in ['/root/k70/rt/*','/root/k70/containers/*','/root/k70/qemu-fw/*','/root/k70/*.fd','/root/k70/*.img','/root/k70/*.bin']:
    files += glob.glob(pat)
for f in sorted(set(files)):
    if not os.path.isfile(f): continue
    try: b=open(f,'rb').read()
    except: continue
    i=b.find(g)
    print('%-50s %10d %s' % (f, len(b), hex(i) if i>=0 else '-'))
EOF
