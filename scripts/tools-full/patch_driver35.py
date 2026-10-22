import re, sys, pathlib

p = pathlib.Path('/mnt/d/\u672c\u5730\u9879\u76ee-01/_k70port_extract/port-drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.c')
s = p.read_text(encoding='gbk')

if 'keys35: dump the structures' in s:
    print('already patched'); sys.exit(0)

p.with_suffix('.c.bak35').write_text(s, encoding='gbk')
nl = '\r\n' if '\r\n' in s else '\n'
def N(x): return x.replace('\n', nl)

# 1) capture the three payload addresses inside DumpHobs
old = N('''    } else if ((GuidHob->Name.Data1 == 0x90A49AFD) ||
               (GuidHob->Name.Data1 == 0xBEDAEABC) ||
               (GuidHob->Name.Data1 == 0xD5F8D706) ||
               (GuidHob->Name.Data1 == 0x8EC2BD8D) ||
               (GuidHob->Name.Data1 == 0x12DBD93D))
    {
      DumpHobWords (GuidHob, Hob);
    }
''')
new = N('''    } else if ((GuidHob->Name.Data1 == 0x90A49AFD) ||
               (GuidHob->Name.Data1 == 0xBEDAEABC) ||
               (GuidHob->Name.Data1 == 0xD5F8D706) ||
               (GuidHob->Name.Data1 == 0x8EC2BD8D) ||
               (GuidHob->Name.Data1 == 0x12DBD93D))
    {
      DumpHobWords (GuidHob, Hob);
      switch (GuidHob->Name.Data1) {
        case 0x90A49AFD: mInfoBlkAddr = *(UINT64 *)GET_GUID_HOB_DATA (Hob); break;
        case 0xBEDAEABC: mShimAddr    = *(UINT64 *)GET_GUID_HOB_DATA (Hob); break;
        case 0x8EC2BD8D: mSchedAddr   = *(UINT64 *)GET_GUID_HOB_DATA (Hob); break;
        default: break;
      }
    }
''')
assert s.count(old) == 1, 'hob capture anchor %d' % s.count(old)
s = s.replace(old, new, 1)

# 2) globals
anchor = 'STATIC UINT64     mDtbExtnAddr   = 0;'
assert s.count(anchor) == 1
s = s.replace(anchor, anchor + N('''
// keys35: payloads of the Info Blk / Shim / Scheduler interface HOBs.  These are the only
// numbers XBL actually handed PEI, so they are the last honest lead to the live device tree.
STATIC UINT64     mInfoBlkAddr    = 0;
STATIC UINT64     mShimAddr       = 0;
STATIC UINT64     mSchedAddr      = 0;'''), 1)

# 3) new dumper function + entry call
tail_anchor = N('''  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== HALTING (keys34 hob payload dump) ====\\n"));
''')
assert s.count(tail_anchor) == 1, 'halt anchor %d' % s.count(tail_anchor)

dumper = N('''//
// keys35: dump the structures the HOB payloads point at.  Every candidate page is read word by
// word, and each word is FDT-magic checked, so a device tree hiding inside any of them shows up
// as an explicit "FDT!" line instead of another round trip.
//
STATIC
VOID
DumpWordsAt (
  IN CONST CHAR8  *What,
  IN UINT64       Addr,
  IN UINTN        Words
  )
{
  UINTN        Index;
  CONST UINT8  *P;
  UINT32       Magic;

  if (Addr == 0) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " %a: null\\n", What));
    return;
  }
  //
  // Only addresses the firmware itself reported are touched here: they came out of the HOBs, so
  // they live in memory PEI already mapped (Info Blk ended up as an RT_Data page in the DXE map).
  //
  P     = (CONST UINT8 *)(UINTN)Addr;
  Magic = RdBe32 (P);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " %a @0x%lx magic=%08x%s\\n",
          What, Addr, Magic, (Magic == 0xD00DFEED) ? " FDT!" : ""));
  for (Index = 0; Index < Words; Index++) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   [0x%x] %016lx\\n", (UINT32)(Index * 8), RdLe64 (P + Index * 8)));
  }
  if (Magic == 0xD00DFEED) {
    WalkFdt (P, RdBe32 (P + 4));
    return;
  }
  for (Index = 0; Index < Words; Index++) {
    Magic = RdBe32 (P + Index * 8);
    if (Magic == 0xD00DFEED) {
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   ^^ FDT at 0x%lx totalsize=0x%x\\n",
              Addr + Index * 8, RdBe32 (P + Index * 8 + 4)));
      WalkFdt (P + Index * 8, RdBe32 (P + Index * 8 + 4));
    }
  }
}

STATIC
VOID
DumpHobPayloadPages (
  VOID
  )
{
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== hob payload pages ====\\n"));
  DumpWordsAt ("InfoBlk", mInfoBlkAddr, 32);
  DumpWordsAt ("Shim",    mShimAddr,    16);
  DumpWordsAt ("Sched",   mSchedAddr,   16);
  DumpWordsAt ("DtbExtn", mDtbExtnAddr, 8);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== hob payload pages end ====\\n"));
}

''')
s = s.replace(tail_anchor, dumper + tail_anchor, 1)
s = s.replace(tail_anchor, N('''  DumpHobPayloadPages ();

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== HALTING (keys35 hob payload pages) ====\\n"));
'''), 1)

p.write_text(s, encoding='gbk')
print('patched', p)
