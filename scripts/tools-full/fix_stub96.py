import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_tools/patch_stub96.py')
s = p.read_text(encoding='utf-8')
old = "    assert m, 'no vermeer driver INF lines in fdf'"
new = "    if not m:\n        print('fdf: no direct INF lines (uses APRIORI.inc include) - skip')\n        m = None\n    else:\n        pass"
assert old in s
s = s.replace(old, new, 1)
# 重新组织后续逻辑：只有 m 非 None 才插入
old2 = """    last = m[-1]
    s = s[:last.end()] + 'INF ' + INF_REL + '\\n' + s[last.end():]
    fdf.write_text(s, encoding='utf-8')
    print('fdf: added')"""
new2 = """    if m:
        last = m[-1]
        s = s[:last.end()] + 'INF ' + INF_REL + '\\n' + s[last.end():]
        fdf.write_text(s, encoding='utf-8')
        print('fdf: added')"""
assert old2 in s
s = s.replace(old2, new2, 1)
p.write_text(s, encoding='utf-8')
print('patched')