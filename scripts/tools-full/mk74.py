import io
p='/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if 'UFS74_DUMPONLY' in s:
    print('already'); raise SystemExit
old='''  UfsPrint ("[UFS71] host idle ok\\n");'''
new='''  UfsPrint ("[UFS71] host idle ok\\n");

#if defined (UFS74_DUMPONLY)
  {
    UINT32  o;
    for (o = 0x00; o <= 0x80; o += 4) {
      AsciiSPrint (Line, sizeof (Line), "[UFS74] r%02x=%08x\\n", o, UfsRd (o));
      UfsPrint (Line);
    }
    for (o = 0x00; o <= 0x30; o += 4) {
      AsciiSPrint (Line, sizeof (Line), "[UFS74] smmu%03x=%08x\\n", o, SmmuRd (o));
      UfsPrint (Line);
    }
    AsciiSPrint (Line, sizeof (Line), "[UFS74] cap=%08x cards=%08x smmu_id2=%08x\\n",
                 UfsRd (0x00), UfsRd (0x24), SmmuRd (0x28));
    UfsPrint (Line);
    UfsPrint ("[UFS74] DUMP ONLY - no doorbell, rebooting is safe\\n");
    return;
  }
#endif'''
assert old in s
s=s.replace(old,new,1)
io.open(p,'w',encoding='utf-8').write(s)
print('dump-only inserted')