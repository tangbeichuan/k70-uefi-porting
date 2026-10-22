import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8')

old = '''  Guard = 0;
  if ((SmmuRd (0x20) != 0x4c017e69) || (SmmuRd (0x24) != 0x60000046) ||
      (SmmuRd (0x00) != 0x00280406) || (SmmuRd (0x800) != 0x80000060) ||
      (SmmuRd (0xc00) != 0))'''
new = '''  Guard = 0;

  //
  // keys95: 把 SMMU 的五个判据全部打出来（先前只有一个合成的 guard 值，无法定位）
  //
  AsciiSPrint (Line, sizeof (Line),
               "[UFS95] smmu idr0=%08x idr1=%08x cr0=%08x smr0=%08x s2cr0=%08x id2=%08x\\n",
               SmmuRd (0x20), SmmuRd (0x24), SmmuRd (0x00), SmmuRd (0x800),
               SmmuRd (0xc00), SmmuRd (0x28));
  UfsPrint (Line);
  AsciiSPrint (Line, sizeof (Line),
               "[UFS95] smmu ctx0=%08x cb0=%08x gbpa=%08x\\n",
               SmmuRd (0x1000), SmmuRd (0x80000), SmmuRd (0x1008));
  UfsPrint (Line);

  if ((SmmuRd (0x20) != 0x4c017e69) || (SmmuRd (0x24) != 0x60000046) ||
      (SmmuRd (0x00) != 0x00280406) || (SmmuRd (0x800) != 0x80000060) ||
      (SmmuRd (0xc00) != 0))'''
assert old in s
s = s.replace(old, new, 1)

# guard != 0 时停手（照 ios-vermeer-lab：SMMU 不是期望状态就不要敲门铃）
old2 = '''  AsciiSPrint (Line, sizeof (Line), "[UFS71] smmu guard (0=ok)=%d  id2=0x%x\\n", Guard, SmmuRd (0x28));
  UfsPrint (Line);'''
new2 = old2 + '''

  if (Guard != 0) {
    UfsPrint ("[UFS95] SMMU guard failed - stop before doorbell (safe)\\n");
    return;
  }'''
assert old2 in s
s = s.replace(old2, new2, 1)
p.write_text(s, encoding='utf-8')
print('patched keys95: smmu detail + stop on guard')