import pathlib

p = pathlib.Path('/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c')
s = p.read_text(errors='surrogateescape')
pathlib.Path('/tmp/PlatformPei.c.bak42').write_text(s, errors='surrogateescape')

old = """  // Build DTB Extension HOB
  if (DtbExtensionAddr) {
    BuildGuidDataHob (&gEfiDtbExtensionHobGuid, &DtbExtensionAddr, sizeof (DtbExtensionAddr));
  }"""
new = """  // keys42: build every HOB EnvDxe needs (Info Blk / Shim / Prodmode / Scheduler) but NOT the
  // DTB Extension HOB.  XblProtocols.parse hands back the address of a GUID literal instead of a
  // live 0x108-byte interface, so publishing that HOB only makes EnvDxe dereference garbage
  // (FAR 0x049D2B073D213397) and kill the whole dispatch.  With the HOB absent, EnvDxe takes the
  // EFI_NOT_FOUND path, exactly like the builds where the vendor stack was known good.
  if (0 && DtbExtensionAddr) {
    BuildGuidDataHob (&gEfiDtbExtensionHobGuid, &DtbExtensionAddr, sizeof (DtbExtensionAddr));
  }"""
assert old in s, 'anchor missing'
p.write_text(s.replace(old, new, 1), errors='surrogateescape')
print('PlatformPei.c: DTB Extension HOB disabled (keys42)')
