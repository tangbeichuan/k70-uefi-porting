import pathlib

p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.c')
raw = p.read_bytes().decode('gbk')
s = raw.replace('\r\n', '\n').replace('\r', '\n')

if 'UiDeferredStart' in s:
    print('already patched')
    raise SystemExit

block = '''STATIC EFI_EVENT  mUiEvent = NULL;

STATIC
VOID
EFIAPI
UiNotify (
  IN EFI_EVENT  Event,
  IN VOID       *Context
  )
{
  gBS->CloseEvent (Event);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== deferred UI fired ====\\n"));
  InteractiveDemo ();
}

//
// keys38: the probe is dispatched second, long before ConSplitter/GraphicsConsole exist, so the
// interactive part is armed as a 5 s one-shot timer instead of running inline.  By the time the
// timer fires, DXE dispatch has finished (or died), and gST->ConIn/ConOut are whatever BDS has.
//
STATIC
VOID
UiDeferredStart (
  VOID
  )
{
  EFI_STATUS  Status;

  Status = gBS->CreateEvent (EVT_TIMER, TPL_CALLBACK, UiNotify, NULL, &mUiEvent);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "timer create failed: %r\\n", Status));
    return;
  }
  gBS->SetTimer (mUiEvent, TimerRelative, 5ull * 1000ull * 1000ull * 10ull);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "deferred UI armed (fires in 5 s)\\n"));
}

'''

anchor = 'STATIC\nEFI_STATUS\nEFIAPI\nVermeerDtDumpDxeEntry ('
if anchor not in s:
    anchor = 'EFI_STATUS\nEFIAPI\nVermeerDtDumpDxeEntry ('
assert anchor in s, 'entry anchor not found'
s = s.replace(anchor, block + anchor, 1)

old_tail = '''  DumpHobPayloadPages ();

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== HALTING (keys35 hob payload pages) ====\\n"));
  CpuDeadLoop ();'''
new_tail = '''  DumpHobPayloadPages ();

  //
  // keys38: do NOT halt here.  Arm the console/UI check for later, then let DXE dispatch continue
  // so we can see whether EnvDxe survives without the DTB-Extension HOB.
  //
  UiDeferredStart ();'''
assert old_tail in s, 'tail anchor not found'
s = s.replace(old_tail, new_tail, 1)

p.write_bytes(s.replace('\n', '\r\n').encode('gbk'))
print('keys38 driver patch applied')
