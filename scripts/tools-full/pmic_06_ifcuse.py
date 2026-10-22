#!/usr/bin/env python3
import re, sys
ASM = "/tmp/pmic/pmic.asm"
lines = open(ASM, encoding="utf-8", errors="replace").read().splitlines()
pat = re.compile(r'^\s*([0-9a-f]+):\s*(?:[0-9a-f]{8}\s+)?(.*)$')
insns = []
for ln in lines:
    m = pat.match(ln)
    if m:
        insns.append((int(m.group(1),16), m.group(2).strip().lower()))

# Use capstone for real operand regs if available
try:
    import capstone
except ImportError:
    capstone = None
print("capstone:", capstone is not None)
if not capstone:
    sys.exit(0)

md = capstone.Cs(capstone.CS_ARCH_ARM64, capstone.CS_MODE_ARM)
code = open("/tmp/pmic/text.bin","rb").read()
BASE = 0x1000
regname = {}
for ins in md.disasm(code, BASE):
    regname[ins.address] = ins

TARGET_GLOBALS = {0x353a8: "DTBExtn", 0x353c8: "IFC2", 0x353c0: "IFC2raw", 0x353b8: "?", 0x36750: "IFC3"}
# scan per function: detect function start heuristically at 'stp x29, x30' or addresses that are bl targets
# simpler: linear scan with reg value tracking reset at each ret
addr2idx = {a:i for i,(a,t) in enumerate(insns)}

def is_func_start(a):
    i = addr2idx[a]
    if i==0: return True
    prev = insns[i-1][1]
    return prev.startswith('ret') or prev.startswith('b\t') is False and (prev in ('nop','udf\t#0x0') or prev.startswith('udf'))

cur = {}
state = {}
results=[]
for i,(a,text) in enumerate(insns):
    ins = regname.get(a)
    if not ins:
        cur.clear(); continue
    mn = ins.mnemonic
    ops = ins.operands
    # reset on ret
    if mn == 'ret':
        cur.clear(); continue
    if mn == 'adrp':
        rd = ins.reg_name(ops[0].reg); imm = ops[1].imm
        cur[rd] = ('abs', imm)
        continue
    if mn == 'add' and len(ops)==3 and ops[2].type==capstone.arm64.ARM64_OP_IMM:
        rd=ins.reg_name(ops[0].reg); rs=ins.reg_name(ops[1].reg)
        if rs in cur and cur[rs][0]=='abs':
            cur[rd] = ('abs', cur[rs][1]+ops[2].imm)
        else:
            cur[rd]=('unknown',)
        continue
    if mn == 'mov' and len(ops)==2 and ops[0].type==capstone.arm64.ARM64_OP_REG and ops[1].type==capstone.arm64.ARM64_OP_REG:
        rd=ins.reg_name(ops[0].reg); rs=ins.reg_name(ops[1].reg)
        cur[rd]=cur.get(rs,('unknown',))
        continue
    if mn == 'ldr' and len(ops)==2:
        rd=ins.reg_name(ops[0].reg)
        mem=ops[1].mem
        if mem.base and mem.disp is not None:
            bs=ins.reg_name(mem.base)
            if bs in cur and cur[bs][0]=='abs':
                gaddr = cur[bs][1]+mem.disp
                if gaddr in TARGET_GLOBALS:
                    cur[rd]=('iface', gaddr)
                    continue
                else:
                    cur[rd]=('mem', gaddr)
                    continue
            elif bs in cur and cur[bs][0]=='iface':
                cur[rd]=('method', cur[bs][1], mem.disp, a)
                results.append((a, cur[bs][1], mem.disp, rd))
                continue
        cur[rd]=('unknown',)
        continue
    # any other write to rd invalidates
    for op in ops:
        if op.type==capstone.arm64.ARM64_OP_REG and op.access & capstone.CS_AC_WRITE:
            cur[ins.reg_name(op.reg)] = ('unknown',)

print("\n=== method-pointer loads from tracked globals ===")
for a,g,slot,rd in results:
    print(f"load@{a:06x} iface=0x{g:x} slot=+0x{slot:x} -> {rd}")

# also check for br reg
print("\n=== br sites ===")
for i,(a,text) in enumerate(insns):
    if re.fullmatch(r'br\s+x\d+', text):
        print(f"{a:06x}: {text}")
