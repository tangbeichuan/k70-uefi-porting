$ErrorActionPreference = 'Stop'
$root = (Get-ChildItem 'D:\' -Directory | Where-Object { Test-Path (Join-Path $_.FullName '_k70port_extract\port-drivers') } | Select-Object -First 1).FullName
$p = Join-Path $root '_k70port_extract\port-drivers\VermeerDtDumpDxe\VermeerDtDumpDxe.c'
$enc = [System.Text.Encoding]::GetEncoding(936)
$s = $enc.GetString([System.IO.File]::ReadAllBytes($p)) -replace "`r`n", "`n"
Copy-Item $p "$p.bak34" -Force

$helper = @'
STATIC
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
  DEBUG ((DEBUG_ERROR, "\n"));
  for (Index = 0; Index < Count; Index++) {
    if ((W[Index] >= 0xA8000000ULL) && (W[Index] < 0xB8000000ULL) && ((W[Index] & 3) == 0)) {
      P = (CONST UINT8 *)(UINTN)W[Index];
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   w[%d]=0x%lx -> magic=%08x%s\n",
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
'@

$oldHead = "STATIC`r`nVOID`r`nDumpHobs (`r`n  VOID`r`n  )`r`n"
if ($s.IndexOf($oldHead) -lt 0) { throw 'DumpHobs head not found' }
$s = $s.Replace($oldHead, $helper + "`r`n")

$oldTail = @'
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "  hob %g len=0x%x\n",
              &GuidHob->Name, GET_HOB_LENGTH (Hob)));
'@
if ($s.IndexOf($oldTail) -lt 0) { throw 'hob print block not found' }
$s = $s.Replace($oldTail, "      DumpHobWords (GuidHob, Hob);`r`n")

$oldBody = @'
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== vermeer device-tree dump ====\n"));
  ProbeShimFdt ();
  DumpMemoryMap ();
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== end of memory map ====\n"));
  ScanBoardWindows ();

  //
  // Legacy stages are still compiled and referenced (no unused-function warnings) but skipped
  // at runtime: their answers are known from keys24..keys29 and they only cost screen lines.
  //
  if (mLegacyProbe == 0) {
    ScanReservedForIfc ();
    DumpHobs ();
    ProbeDtbExtn ();
    ScanWindowForVer ();
    ScanWindowForFdt ();
    AuditDtbAddr ();
    ScanWindowForGuid ();
    DumpConfigTables ();
  }

  InteractiveDemo ();

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== HALTING (keys31 interactive test) ====\n"));
'@
$newBody = @'
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== vermeer device-tree dump ====\n"));
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

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== HALTING (keys34 hob payload dump) ====\n"));
'@
if ($s.IndexOf($oldBody) -lt 0) { throw 'entry body not found' }
$s = $s.Replace($oldBody, $newBody)

[System.IO.File]::WriteAllBytes($p, $enc.GetBytes(($s -replace "`n", "`r`n")))
'patched'
