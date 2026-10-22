import pathlib
p = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerUfsMapDxe/VermeerUfsMapDxe.c")
s = p.read_text(encoding="utf-8")
i = s.find("  //\n  // keys147c:")
if i < 0:
    print("marker not found; file may already be reverted")
else:
    # find the end: the closing of the block followed by return
    j = s.find("  return EFI_SUCCESS;\n}", i)
    assert j > 0, "no return after marker"
    s = s[:i] + s[j:]
    p.write_text(s, encoding="utf-8")
    print("reverted, VBUS present:", "[VBUS]" in s)
print("tail:")
print("\n".join(s.splitlines()[-8:]))