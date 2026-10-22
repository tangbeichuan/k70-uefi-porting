import pathlib
p = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c")
s = p.read_text(encoding="utf-8")
print("has VBUS already:", "[VBUS]" in s)
# locate the entry function's final return
marker = "VermeerDtbExtnDxeEntry ("
i = s.find(marker)
assert i > 0, "entry not found"
tail = s[i:]
k = tail.find("\n  return EFI_SUCCESS;\n}")
assert k > 0, "final return not found in entry"
block = '''
  //
  // keys147c: force the Qualcomm QSCRATCH "VBUS valid" override so the DWC3
  // device controller pulls up D+ and enumerates on the host.  Ported from
  // xyyyds0106/ios-vermeer-lab (xnu 0074-sweet-usb-vbus-override.patch);
  // Linux dwc3-qcom does dwc3_qcom_vbus_override_enable() after cable detect.
  //
  {
    UINT32  Gen, Hs, Ss, Gctl, Dctl, Dsts;

    Gen  = *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x08);
    Hs   = *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x10);
    Ss   = *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x30);
    Gctl = *(volatile UINT32 *)(UINTN)(0x0A600000ULL + 0xC110);
    Dctl = *(volatile UINT32 *)(UINTN)(0x0A600000ULL + 0xC700);
    Dsts = *(volatile UINT32 *)(UINTN)(0x0A600000ULL + 0xC704);

    DEBUG ((DEBUG_ERROR,
            "[VBUS] before: GEN=%08x HS=%08x SS=%08x GCTL=%08x DCTL=%08x DSTS=%08x\\n",
            Gen, Hs, Ss, Gctl, Dctl, Dsts));

    *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x10) = Hs | (1U << 20) | (1U << 28);
    *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x30) = Ss | (1U << 24);
    MemoryFence ();

    Hs   = *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x10);
    Ss   = *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x30);
    Dctl = *(volatile UINT32 *)(UINTN)(0x0A600000ULL + 0xC700);
    Dsts = *(volatile UINT32 *)(UINTN)(0x0A600000ULL + 0xC704);

    DEBUG ((DEBUG_ERROR,
            "[VBUS] after : HS=%08x SS=%08x DCTL=%08x DSTS=%08x\\n",
            Hs, Ss, Dctl, Dsts));
  }

'''
new_tail = tail[:k+1] + block + tail[k+1:]
s = s[:i] + new_tail
p.write_text(s, encoding="utf-8")
print("patched provider, VBUS:", "[VBUS]" in s)