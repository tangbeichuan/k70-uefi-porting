import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8', errors='surrogateescape')

# 1) enable the UFS test in this build
s = s.replace('STATIC UINTN  mSkipUfsTest = 1;', 'STATIC UINTN  mSkipUfsTest = 0;', 1)

# 2) after the UIC block, check PA_LINKUP (UECPA) and refuse to ring the doorbell when link is down
anchor = '    UfsPrint ("[UFS75] UIC DONE\\n");'
assert anchor in s, 'uic anchor missing'
inject = anchor + '''

    {
      UINT32  Uecpa = UfsRd (0x64);
      UINTN   Try;
      for (Try = 0; Try < 200; Try++) {
        Uecpa = UfsRd (0x64);
        if ((Uecpa & 1) != 0) {
          break;
        }
        gBS->Stall (1000);
      }

      AsciiSPrint (Line, sizeof (Line), "[UFS106] UECPA=%08x link_up=%d tries=%d\\n",
                   Uecpa, (Uecpa & 1) ? 1 : 0, (UINT32)Try);
      UfsPrint (Line);

      if ((Uecpa & 1) == 0) {
        UfsPrint ("[UFS106] PA_LINKUP=0 - UniPro link is down, DO NOT ring doorbell (safe stop)\\n");
        return;
      }
    }
'''
s = s.replace(anchor, inject, 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('probe patched keys106')