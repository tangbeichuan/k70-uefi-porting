import io, sys
src = "/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c"
blk = open("/mnt/d/本地项目-01/_tools/k148_block.c", encoding="utf-8").read()
txt = open(src, encoding="utf-8").read()
m = txt.find("// keys147c: force the Qualcomm QSCRATCH")
assert m > 0, "marker not found"
start = txt.rfind("  //\n", 0, m)
assert start >= 0, "start line not found"
endm = "(Dsts2 >> 22) & 1));"
e = txt.find(endm, m)
assert e > 0, "end marker not found"
end = txt.find("\n  }", e) + len("\n  }")
old = txt[start:end]
print("old block chars:", len(old))
new = blk.rstrip("\n")
txt2 = txt[:start] + new + txt[end:]
open(src, "w", encoding="utf-8", newline="\n").write(txt2)
print("new file chars:", len(txt2))