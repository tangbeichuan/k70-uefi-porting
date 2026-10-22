$ErrorActionPreference = 'Stop'
$root = (Get-ChildItem 'D:\' -Directory | Where-Object { Test-Path (Join-Path $_.FullName '_k70port_extract\port-drivers') } | Select-Object -First 1).FullName
$p = Join-Path $root '_k70port_extract\port-drivers\VermeerDtDumpDxe\VermeerDtDumpDxe.c'
$enc = [System.Text.Encoding]::GetEncoding(936)
$s = $enc.GetString([System.IO.File]::ReadAllBytes($p))

if ($s.IndexOf('ProbeShimFdt (') -ge 0) {
  'already patched'
} else {
  Copy-Item $p "$p.bak33" -Force

  $new = @'
//
// keys33: our BootShim now publishes the x0 that ABL hands the boot image -- the live
// device tree -- at 0xA700FFF0: {u32 magic 0x46445442 ("BTDF" in memory), u64 fdt}.
// The reference K70 XNU bring-up (ios-vermeer-lab boot/loader.c) expects that pointer in
// 0xB5D00000..0xB5F00000, which our memory map already maps through the "Kernel"
// descriptor (0xA8000000 + 0x10000000), so both reading it and scanning that window are
// safe.  This is the tree the firmware never installed and every vendor driver wants.
//
#define DTDUMP_SHIM_SLOT   0xA700FFF0ULL
#define DTDUMP_SHIM_MAGIC  0x46445442U

STATIC
VOID
ProbeShimFdt (
  VOID
  )
{
  CONST UINT8  *Slot;
  UINT32       Magic;
  UINT64       Fdt;
  CONST UINT8  *P;
  UINT32       FdtMagic;
  UINT32       Total;
  UINT64       Probe;

  Slot  = (CONST UINT8 *)(UINTN)DTDUMP_SHIM_SLOT;
  Magic = (UINT32)(RdLe64 (Slot) & 0xFFFFFFFFULL);
  Fdt   = RdLe64 (Slot + 8);

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== shim live-FDT slot ====\n"));
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " slot 0x%lx magic=%08x (want %08x) fdt=0x%lx\n",
          DTDUMP_SHIM_SLOT, Magic, DTDUMP_SHIM_MAGIC, Fdt));

  if ((Magic == DTDUMP_SHIM_MAGIC) && (Fdt >= 0xA8000000ULL) && (Fdt < 0xB8000000ULL) &&
      ((Fdt & 3) == 0))
  {
    P        = (CONST UINT8 *)(UINTN)Fdt;
    FdtMagic = RdBe32 (P);
    Total    = RdBe32 (P + 4);
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " live fdt magic=%08x totalsize=0x%x %s\n",
            FdtMagic, Total, (FdtMagic == 0xD00DFEED) ? "OK" : "BAD"));
    if (FdtMagic == 0xD00DFEED) {
      WalkFdt (P, Total);
    }
  } else if (Magic == DTDUMP_SHIM_MAGIC) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " fdt 0x%lx outside the mapped Kernel window\n", Fdt));
  }

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " scan 0xB5D00000..0xB5F00000 for FDT magic\n"));
  for (Probe = 0xB5D00000ULL; Probe < 0xB5F00000ULL; Probe += 0x10000ULL) {
    P = (CONST UINT8 *)(UINTN)Probe;
    if (RdBe32 (P) == 0xD00DFEED) {
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG " FDT found at 0x%lx totalsize=0x%x\n",
              Probe, RdBe32 (P + 4)));
      WalkFdt (P, RdBe32 (P + 4));
      break;
    }
  }
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== shim live-FDT slot end ====\n"));
}

'@

  $anchor = 'STATIC CONST EFI_GUID  mGopGuid = {'
  if ($s.IndexOf($anchor) -lt 0) { throw 'anchor missing' }
  $s = $s.Replace($anchor, $new + $anchor)

  $phrase = '==== vermeer device-tree dump ===='
  $at = $s.IndexOf($phrase)
  if ($at -lt 0) { throw 'banner not found' }
  $close = $s.IndexOf('));', $at)
  if ($close -lt 0) { throw 'banner close not found' }
  $cut = $close + 3
  $s = $s.Insert($cut, "`r`n  ProbeShimFdt ();")

  [System.IO.File]::WriteAllBytes($p, $enc.GetBytes($s))
  'patched'
}
Select-String -Path $p -Pattern 'ProbeShimFdt \(\)|DTDUMP_SHIM_SLOT  ' | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
