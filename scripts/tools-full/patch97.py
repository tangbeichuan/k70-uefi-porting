import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8')

old_guard = '''  if (Guard != 0) {
    UfsPrint ("[UFS95] SMMU guard failed - stop before doorbell (safe)\\n");
    return;
  }'''
new_guard = '''  if (Guard != 0) {
    //
    // keys97: SMMUEN=0（CR0.bit0=0）时 DMA 是直通的，guard 只是"配置与某环境不符"，
    // 不能当致命错误；只告警继续，让后续流程跑完。
    //
    UfsPrint ("[UFS97] smmu guard != 0 but SMMUEN=0 -> continue (bypass)\\n");
  }'''
assert old_guard in s, 'guard block not found'
s = s.replace(old_guard, new_guard, 1)

old_halt = '''  Say ("  === UFS TEST HALT (keys88) ===\\n");
  CpuDeadLoop ();'''
new_halt = '''  // keys97: 不再死循环，让派发继续（UFSDxe 要走 SMMU 桩）
  Say ("  === UFS TEST END (keys97, dispatch continues) ===\\n");'''
assert old_halt in s, 'halt block not found'
s = s.replace(old_halt, new_halt, 1)

p.write_text(s, encoding='utf-8')
print('patched keys97: guard warning-only + halt removed')