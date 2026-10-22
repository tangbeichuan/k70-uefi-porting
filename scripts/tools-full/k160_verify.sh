#!/usr/bin/env bash
set -e
cd /mnt/d/本地项目-01/_tools
python3 - <<'PY'
import io
s = io.open('verify159.py', encoding='utf-8').read()
s = s.replace('159', '160').replace('keys158', 'keys159').replace('keys160', 'keys160')
# baseline: keys159 (same as keys158 except Menu), so all strings above are consistent
io.open('verify160.py', 'w', encoding='utf-8', newline='\n').write(s)
print('wrote verify160.py', len(s))
PY
grep -n 'BASE =' verify160.py | head -3
