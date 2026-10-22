import pathlib

p = pathlib.Path('/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c')
s = p.read_text(errors='surrogateescape')
pathlib.Path('/tmp/PlatformPei.c.bak43').write_text(s, errors='surrogateescape')

# 1) Scheduler Interface HOB: its payload is the same bogus address (0xA703A290 = a GUID literal
#    page), and EnvDxe reads +0x58 of it -> FAR 0x049D2B073D213397.
old_sched = """  // Check Scheduler Address
  if (SchedulerInterfaceAddr) {"""
new_sched = """  // Check Scheduler Address
  // keys43: do NOT publish the Scheduler Interface HOB either.  XblProtocols.parse returns the
  // address of a GUID literal for both the scheduler and the DTB extension, so publishing it makes
  // EnvDxe treat a rodata page as a 0x108-byte interface and dereference +0x58 -> FAR
  // 0x049D2B073D213397.  Info Blk / Shim / Prodmode HOBs are still published.
  if (0 && SchedulerInterfaceAddr) {"""
assert old_sched in s, 'scheduler anchor'
s = s.replace(old_sched, new_sched, 1)

# 2) DTB Extension HOB stays disabled as well.
old_dtb = """  // Build DTB Extension HOB
  if (DtbExtensionAddr) {"""
new_dtb = """  // Build DTB Extension HOB
  // keys43: disabled (see the scheduler note above); EnvDxe takes the EFI_NOT_FOUND path instead.
  if (0 && DtbExtensionAddr) {"""
assert old_dtb in s, 'dtb anchor'
s = s.replace(old_dtb, new_dtb, 1)

p.write_text(s, errors='surrogateescape')
print('PlatformPei.c: scheduler + DTB extension HOBs disabled (keys43)')
