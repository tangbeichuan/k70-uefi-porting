set +e
F=/root/k70/uefi/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFb.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys114' in s:
    print('already patched'); raise SystemExit
# 1) mark entry
s = s.replace('''  EFI_PHYSICAL_ADDRESS BaseAddress;
  UINT32               Width;
  UINT32               Height;
  UINT32               ColorDepth;

  // Get Frame Buffer Infos
  Status = GetFrameBufferInfos (&BaseAddress, &Width, &Height, &ColorDepth);''',
'''  EFI_PHYSICAL_ADDRESS BaseAddress;
  UINT32               Width;
  UINT32               Height;
  UINT32               ColorDepth;

  DEBUG ((EFI_D_ERROR, "[FB] RegisterFrameBuffer enter (keys114)\\n"));   // keys114

  // Get Frame Buffer Infos
  Status = GetFrameBufferInfos (&BaseAddress, &Width, &Height, &ColorDepth);''', 1)
# 2) report region and resolution
s = s.replace('''  // Verify Frame Buffer Region
  if (!FrameBufferRegion.Address) {''',
'''  DEBUG ((EFI_D_ERROR, "[FB] Display Reserved = 0x%lx size=0x%lx (keys114)\\n",
          (UINT64)FrameBufferRegion.Address, (UINT64)FrameBufferRegion.Length));   // keys114
  // Verify Frame Buffer Region
  if (!FrameBufferRegion.Address) {''', 1)
s = s.replace('''  // Pass Frame Buffer Address
  *BaseAddress = FrameBufferRegion.Address;''',
'''  DEBUG ((EFI_D_ERROR, "[FB] W=%u H=%u Depth=%u (keys114)\\n", *Width, *Height, *ColorDepth));   // keys114
  // Pass Frame Buffer Address
  *BaseAddress = FrameBufferRegion.Address;''', 1)
s = s.replace('''  // Free Memory Buffers
  FreeMemoryBuffers ();

  return Status;''',
'''  // Free Memory Buffers
  FreeMemoryBuffers ();
  DEBUG ((EFI_D_ERROR, "[FB] exit with %r (keys114)\\n", Status));   // keys114
  return Status;''', 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('SimpleFb instrumented (keys114)')
PY
grep -c "keys114" "$F"