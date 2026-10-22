import pathlib

p = pathlib.Path('/mnt/d/本地项目-01/_tools/verify161.py')
s = p.read_text(encoding='utf-8')
assert 'BASE = "keys159"' in s
s = s.replace('BASE = "keys159"', 'BASE = "keys160"')
old = '"poll: DSTS", "evt raw", "regs3:", "dep n="'
assert s.count(old) == 1, s.count(old)
s = s.replace(old, '"poll: DCTL", "poll2:", "bringup done", "evt raw", "dep n="')
p.write_text(s, encoding='utf-8', newline='\n')
print('verify161.py: BASE=keys160, Menu strings updated')
