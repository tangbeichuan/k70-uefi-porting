import re, sys, pathlib

p = pathlib.Path('/mnt/d/\u672c\u5730\u9879\u76ee-01/_k70port_extract/port-drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.c')
s = p.read_text(encoding='gbk')

if 'keys34: only dump the GUID HOB payloads' in s:
    print('already patched')
    sys.exit(0)

p.with_suffix('.c.bak34').write_text(s, encoding='gbk')
nl = '\r\n' if '\r\n' in s else '\n'

helper = '''STATIC
VOID
DumpHobWords (
  IN EFI_HOB_GUID_TYPE  *GuidHob,
  IN VOID               *Hob
  )
{
  UINT64       *W;
  UINTN        Count;
  UINTN        Index;
  CONST UINT8  *P;

  Count = (GET_HOB_LENGTH (Hob) - sizeof (EFI_HOB_GUID_TYPE)) / sizeof (UINT64);
  if (Count > 4) {
    Count = 4;
  }
  W = (UINT64 *)GET_GUID_HOB_DATA (Hob);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "  hob %g len=0x%x w=", &GuidHob->Name, GET_HOB_LENGTH (Hob)));
  for (Index = 0; Index < Count; Index++) {
    DEBUG ((DEBUG_ERROR, "%lx ", W[Index]));
  }
  DEBUG ((DEBUG_ERROR, "\\n"));
  for (Index = 0; Index < Count; Index++) {
    if ((W[Index] >= 0xA8000000ULL) && (W[Index] < 0xB8000000ULL) && ((W[Index] & 3) == 0)) {
      P = (CONST UINT8 *)(UINTN)W[Index];
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   w[%d]=0x%lx -> magic=%08x%s\\n",
              Index, W[Index], RdBe32 (P),
              (RdBe32 (P) == 0xD00DFEED) ? " FDT!" : ""));
    }
  }
}

STATIC
VOID
DumpHobs (
  VOID
  )
'''
helper = helper.replace('\n', nl)

head = 'STATIC' + nl + 'VOID' + nl + 'DumpHobs (' + nl + '  VOID' + nl + '  )'
assert s.count(head) == 1, 'DumpHobs head: %d' % s.count(head)
s = s.replace(head, helper, 1)

old_tail = '      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "  hob %g len=0x%x\\n",' + nl + \
           '              &GuidHob->Name, GET_HOB_LENGTH (Hob)));'
assert s.count(old_tail) == 1, 'hob tail: %d' % s.count(old_tail)
s = s.replace(old_tail, '      DumpHobWords (GuidHob, Hob);', 1)

start = s.index('  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== vermeer device-tree dump ====\\n"));')
endmark = '==== HALTING (keys31 interactive test)'
end = s.index(endmark)
new_body = '''  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== vermeer device-tree dump ====\\n"));
  //
  // keys34: only dump the GUID HOB payloads.  keys31/32 faulted on stock unmapped windows
  // (FAR=0x80000000) and keys33 never reached DXE at all, so this build keeps the handler
  // to pure HOB walking: every 64-bit word of every GUID HOB is printed, and any word that
  // points into the mapped Kernel window (0xA8000000..0xB8000000) is FDT-magic checked.
  //
  DumpHobs ();

  if (mLegacyProbe == 0) {
    ProbeShimFdt ();
    DumpMemoryMap ();
    ScanBoardWindows ();
    ScanReservedForIfc ();
    ProbeDtbExtn ();
    ScanWindowForVer ();
    ScanWindowForFdt ();
    AuditDtbAddr ();
    ScanWindowForGuid ();
    DumpConfigTables ();
    InteractiveDemo ();
  }

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== HALTING (keys34 hob payload dump) ====\\n"));
'''.replace('\n', nl)
s = s[:start] + new_body + s[end:]

p.write_text(s, encoding='gbk')
print('patched', p)
