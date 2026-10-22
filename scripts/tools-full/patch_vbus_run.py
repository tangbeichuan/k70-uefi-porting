import pathlib
p = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c")
s = p.read_text(encoding="utf-8")
if "keys147d" in s:
    print("already patched")
else:
    anchor = '''    DEBUG ((DEBUG_ERROR,
            "[VBUS] after : HS=%08x SS=%08x DCTL=%08x DSTS=%08x\\n",
            Hs, Ss, Dctl, Dsts));
  }
'''
    assert anchor in s, "anchor for after-print not found"
    add = '''
  //
  // keys147d: the controller is still halted (DSTS.DEVCTRLHLT=1, DCTL.RUN_STOP=0).
  // Per the ios-vermeer-lab sequence: after the VBUS override, set RUN_STOP and
  // wait for DEVCTRLHLT to clear, otherwise no D+ pull-up ever happens.
  //
  {
    UINT32  Dctl2, Dsts2, N;
    UINT64  Base = 0x0A600000ULL;

    Dctl2 = *(volatile UINT32 *)(UINTN)(Base + 0xC700);
    *(volatile UINT32 *)(UINTN)(Base + 0xC700) = Dctl2 | (1U << 31);
    MemoryFence ();

    Dsts2 = *(volatile UINT32 *)(UINTN)(Base + 0xC704);
    for (N = 0; N < 200 && (Dsts2 & (1U << 22)) != 0; N++) {
      gBS->Stall (1000);
      Dsts2 = *(volatile UINT32 *)(UINTN)(Base + 0xC704);
    }

    Dctl2 = *(volatile UINT32 *)(UINTN)(Base + 0xC700);
    DEBUG ((DEBUG_ERROR,
            "[VBUS] run  : DCTL=%08x DSTS=%08x polls=%d hlt=%d\\n",
            Dctl2, Dsts2, N, (Dsts2 >> 22) & 1));
  }

'''
    s = s.replace(anchor, anchor + add, 1)
    p.write_text(s, encoding="utf-8")
    print("patched keys147d, has run block:", "[VBUS] run" in s)