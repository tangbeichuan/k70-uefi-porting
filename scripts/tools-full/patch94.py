import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
lines = p.read_text(encoding='utf-8').splitlines(keepends=True)

def find(sub, start=0):
    for i in range(start, len(lines)):
        if sub in lines[i]:
            return i
    return -1

i0 = find('// UFS79: 主机控制器复位')
i1 = find('[UFS79] reinit done, takeover next')
if i0 < 0 or i1 < 0:
    print('UFS79 block not found'); raise SystemExit(1)
# 删掉整段（含注释行到 reinit 打印行所在语句）
new_block = ('  // keys94: UFS79 主机复位实验禁用——HCE=1 之后 UCRDY 不会自己回来，\n'
             '  // 会把后面的 takeover / TUR 测试整个挡住。\n'
             '  UfsPrint ("[UFS94] host reset skipped (UFS79 experiment disabled)\\n");\n')
lines[i0:i1+1] = [new_block]
s = ''.join(lines)

# GCC 读取不再依赖 AddMemorySpace 是否成功（PEI 表已经映射过时 GCD 会返回 ACCESS_DENIED）
old_guard = 'if (!EFI_ERROR (GccSt)) {\n      gDS->SetMemorySpaceAttributes (0x00100000ULL, 0x00100000ULL, EFI_MEMORY_UC);\n      AsciiSPrint'
if old_guard in s:
    s = s.replace(old_guard, 'if (1) {\n      gDS->SetMemorySpaceAttributes (0x00100000ULL, 0x00100000ULL, EFI_MEMORY_UC);\n      AsciiSPrint', 1)
    print('gcc read unguarded')
else:
    print('gcc guard pattern not found (check manually)')

p.write_text(s, encoding='utf-8')
print('patched keys94')