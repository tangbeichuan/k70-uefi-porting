import pathlib

p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.c')
raw = p.read_bytes().decode('gbk')
s = raw.replace('\r\n', '\n').replace('\r', '\n')

if 'mLegacyProbe == 2' in s:
    print('already patched')
    raise SystemExit

anchor = """    DumpConfigTables ();
    InteractiveDemo ();
  }"""
new = """    //
    // Dead branch kept only so the crash-prone scanners stay referenced (-Werror=unused-function)
    // without ever running.  Never set mLegacyProbe to 2 on real hardware.
    //
    if (mLegacyProbe == 2) {
      ProbeShimFdt ();
      DumpMemoryMap ();
      ScanBoardWindows ();
      ScanReservedForIfc ();
      ProbeDtbExtn ();
      ScanWindowForVer ();
      ScanWindowForFdt ();
      AuditDtbAddr ();
      ScanWindowForGuid ();
    }

    DumpConfigTables ();
    InteractiveDemo ();
  }"""

assert s.count(anchor) == 1, s.count(anchor)
s = s.replace(anchor, new, 1)
p.write_bytes(s.replace('\n', '\r\n').encode('gbk'))
print('unused-function guard added')
