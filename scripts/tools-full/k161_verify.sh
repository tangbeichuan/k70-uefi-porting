#!/usr/bin/env bash
set -e
cd /mnt/d/本地项目-01/_tools
python3 - <<'PY'
import io
s = io.open('verify160.py', encoding='utf-8').read()
s = s.replace('160', '161')
io.open('verify161.py', 'w', encoding='utf-8', newline='\n').write(s)
print('wrote verify161.py', len(s))
PY
grep -n 'BASE =' verify161.py | head -2
echo '--- patch Menu strings check list ---'
grep -n 'poll: DCTL' verify161.py || true
