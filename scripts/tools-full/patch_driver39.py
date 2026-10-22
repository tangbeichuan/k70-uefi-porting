import pathlib

p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.c')
raw = p.read_bytes().decode('gbk')
s = raw.replace('\r\n', '\n').replace('\r', '\n')

if 'keys39' in s:
    print('already patched for keys39')
    raise SystemExit

# --- replace the notify handler with a periodic, self-describing scout -------------
old_notify = '''STATIC
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
}'''

new_notify = '''STATIC UINTN  mUiTicks = 0;
STATIC UINTN  mKeyCount = 0;
STATIC UINTN  mSel = 0;

STATIC
VOID
UiSay (
  IN CONST CHAR16  *Text
  )
{
  if (gST->ConOut != NULL) {
    gST->ConOut->OutputString (gST->ConOut, (CHAR16 *)Text);
  }
}

//
// keys39: every line is a fixed, formatter-free string, so nothing depends on DEBUG's %-handling
// (the previous build printed "ConIn=?er" because %s was fed a CHAR16 string).  The timer is
// periodic: each tick proves the event loop is alive and re-checks for a real ConIn.
//
STATIC
VOID
EFIAPI
UiNotify (
  IN EFI_EVENT  Event,
  IN VOID       *Context
  )
{
  EFI_STATUS  Status;
  EFI_INPUT_KEY Key;

  mUiTicks++;
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "ui tick\\n"));
  UiSay (L"[UI] tick\\r\\n");

  if (gST->ConIn == NULL) {
    UiSay (L"[UI] ConIn = NULL\\r\\n");
  } else {
    UiSay (L"[UI] ConIn = present\\r\\n");
    Status = gST->ConIn->ReadKeyStroke (gST->ConIn, &Key);
    if (Status == EFI_SUCCESS) {
      mKeyCount++;
      if (Key.ScanCode == 0x01) {
        if (mSel > 0) mSel--;
        UiSay (L"[UI] KEY VOL-UP   -> selection\\r\\n");
      } else if (Key.ScanCode == 0x02) {
        mSel++;
        UiSay (L"[UI] KEY VOL-DOWN -> selection\\r\\n");
      } else {
        UiSay (L"[UI] KEY other\\r\\n");
      }
      UiSay (L"[UI] selected item below\\r\\n");
      if (mSel == 0) UiSay (L"[UI]  > 1  Console facts\\r\\n");
      if (mSel == 1) UiSay (L"[UI]  > 2  Memory map\\r\\n");
      if (mSel == 2) UiSay (L"[UI]  > 3  DTBExtn hunt\\r\\n");
      if (mSel == 3) UiSay (L"[UI]  > 4  About\\r\\n");
    }
  }

  if (gST->ConOut != NULL && (mUiTicks % 5) == 0) {
    UiSay (L"[UI] alive, keys seen so far: press VOL-UP / VOL-DOWN\\r\\n");
  }
}'''

assert old_notify in s, 'notify anchor'
s = s.replace(old_notify, new_notify, 1)

# --- arm a periodic timer instead of a one shot -----------------------------------
old_arm = '''  gBS->SetTimer (mUiEvent, TimerRelative, 5ull * 1000ull * 1000ull * 10ull);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "deferred UI armed (fires in 5 s)\\n"));'''
new_arm = '''  gBS->SetTimer (mUiEvent, TimerPeriodic, 2ull * 1000ull * 1000ull * 10ull);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "periodic UI armed (2 s)\\n"));'''
assert old_arm in s, 'arm anchor'
s = s.replace(old_arm, new_arm, 1)

# --- do not run the blocking InteractiveDemo from the notify path -----------------
s = s.replace('  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== deferred UI fired ====\\n"));\n  InteractiveDemo ();',
              '', 1)

p.write_bytes(s.replace('\n', '\r\n').encode('gbk'))
print('keys39 driver patch applied')
