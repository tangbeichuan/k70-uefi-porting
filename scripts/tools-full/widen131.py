import pathlib, re
p = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c")
s = p.read_text(encoding="utf-8")
n = 0
def rep(m):
    global n
    n += 1
    return m.group(1) + "512);"
s2 = re.sub(r'(return SlotGetGeneric \(0x[0-9a-fA-F]+, "slot 0x[0-9a-fA-F]+", A0, A1, A2, A3, )64\);', rep, s)
p.write_text(s2, encoding="utf-8")
print("slots widened to 512:", n)
PY