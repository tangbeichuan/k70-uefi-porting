import pathlib, re

p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(errors='surrogateescape')

# ---------- includes + tick rate ----------
s = s.replace(
    '#include <Protocol/SimpleTextIn.h>\n',
    '#include <Protocol/SimpleTextIn.h>\n'
    '#include <Library/UefiRuntimeServicesTableLib.h>\n'
    '#include <Library/MemoryAllocationLib.h>\n',
    1)

old_iv = '#define ALIVE_INTERVAL_US       (5 * 1000 * 1000)   // 5 s\n'
new_iv = ('#define ALIVE_INTERVAL_US       (1 * 1000 * 1000)   // 1 s: keys45 runs a menu countdown\n'
          '#define ACTION_DELAY_SECONDS    3\n')
assert old_iv in s
s = s.replace(old_iv, new_iv, 1)

# ---------- menu table + draw + actions ----------
old_items = """STATIC CONST CHAR8 *mMenuItems[4] = {
  "Boot Linux (UFS)",
  "Boot UniXNU",
  "Device information",
  "Reboot / power off"
};

STATIC UINTN  mSelection = 0;
"""
new_items = """STATIC CONST CHAR8 *mMenuItems[5] = {
  "Boot Linux (UFS)",
  "Boot UniXNU",
  "Device information",
  "Reboot",
  "Power off"
};

#define MENU_COUNT  (sizeof (mMenuItems) / sizeof (mMenuItems[0]))

STATIC UINTN  mSelection;
STATIC UINTN  mCountdown;
"""
assert old_items in s
s = s.replace(old_items, new_items, 1)

# replace the DrawMenu body (the one added by patch_probe44)
old_draw_start = s.index('STATIC\nVOID\nDrawMenu (\n  VOID\n  )\n{')
old_draw_end   = s.index('\n}\n', old_draw_start) + len('\n}\n')
new_draw = """STATIC
VOID
PrintDeviceInfo (
  VOID
  )
{
  CHAR8         Line[160];
  UINTN         MapKey, MapSize, DescSize, DescVersion;
  EFI_MEMORY_DESCRIPTOR  *Map;
  UINTN         Pages;
  UINTN         Index;
  UINT64        TotalPages;

  Say ("\\n  [INFO] ---- vermeer platform ----\\n");
  AsciiSPrint (Line, sizeof (Line), "  [INFO] firmware : %a\\n", L"Project Silicium / vermeer (K70)");
  Say (Line);

  Map      = NULL;
  MapSize  = 0;
  MapKey   = 0;
  DescSize = 0;
  DescVersion = 0;
  if (!EFI_ERROR (gBS->GetMemoryMap (&MapSize, Map, &MapKey, &DescSize, &DescVersion))) {
    Say ("  [INFO] memory   : map readable\\n");
  } else {
    Pages      = 0;
    TotalPages = 0;
    MapSize    = 0;
    gBS->GetMemoryMap (&MapSize, NULL, &MapKey, &DescSize, &DescVersion);
    Map = AllocatePool (MapSize + 4 * DescSize);
    if (Map != NULL) {
      if (!EFI_ERROR (gBS->GetMemoryMap (&MapSize, Map, &MapKey, &DescSize, &DescVersion))) {
        Pages = MapSize / DescSize;
        for (Index = 0; Index < Pages; Index++) {
          EFI_MEMORY_DESCRIPTOR  *D;

          D = (EFI_MEMORY_DESCRIPTOR *)((UINT8 *)Map + Index * DescSize);
          if (D->Type == EfiConventionalMemory) {
            TotalPages += D->NumberOfPages;
          }
        }

        AsciiSPrint (Line, sizeof (Line),
                     "  [INFO] memory   : %d descriptors, %d MiB free\\n",
                     (UINT32)Pages, (UINT64)(TotalPages * 4 / 1024));
        Say (Line);
      }

      FreePool (Map);
    }
  }

  {
    UINTN         Handles;
    EFI_HANDLE    *List;
    UINTN         TextIns;

    Handles = 0;
    List    = NULL;
    if (!EFI_ERROR (gBS->LocateHandleBuffer (AllHandles, NULL, NULL, &Handles, &List))) {
      if (List != NULL) {
        gBS->FreePool (List);
      }
    }

    TextIns = 0;
    if (gST->ConIn != NULL) {
      TextIns = 1;
    }

    AsciiSPrint (Line, sizeof (Line),
                 "  [INFO] handles  : %d, ConIn=%a, keys seen=%d\\n",
                 (UINT32)Handles,
                 (gST->ConIn != NULL) ? "yes" : "null",
                 (UINT32)mKeyCount);
    Say (Line);
  }

  Say ("  [INFO] press VOL-UP/DOWN to go back\\n");
}

STATIC
VOID
ActivateSelection (
  VOID
  )
{
  switch (mSelection) {
    case 0:
      Say ("\\n  [ACT] Boot Linux: needs a UFS block device, not available in this build.\\n");
      break;
    case 1:
      Say ("\\n  [ACT] Boot UniXNU: needs an ESP with \\EFI\\UniXNU, not available in this build.\\n");
      break;
    case 2:
      PrintDeviceInfo ();
      break;
    case 3:
      Say ("\\n  [ACT] ResetSystem (cold) ...\\n");
      gBS->Stall (300 * 1000);
      gRT->ResetSystem (EfiResetCold, EFI_SUCCESS, 0, NULL);
      break;
    case 4:
      Say ("\\n  [ACT] ResetSystem (shutdown) ...\\n");
      gBS->Stall (300 * 1000);
      gRT->ResetSystem (EfiResetShutdown, EFI_SUCCESS, 0, NULL);
      break;
    default:
      break;
  }

  mCountdown = ACTION_DELAY_SECONDS;
  DrawMenu ();
}

STATIC
VOID
DrawMenu (
  VOID
  )
{
  CHAR8  Line[128];
  UINTN  Index;

  Say ("\\n  [UI] ==== Vermeer UEFI menu ====\\n");
  for (Index = 0; Index < MENU_COUNT; Index++) {
    AsciiSPrint (
      Line,
      sizeof (Line),
      "  [UI]  %a %d. %a\\n",
      (Index == mSelection) ? ">" : " ",
      (UINT32)(Index + 1),
      mMenuItems[Index]
      );
    Say (Line);
  }

  AsciiSPrint (
    Line,
    sizeof (Line),
    "  [UI]  VOL-UP/DOWN = move, otherwise it acts in %d s (selected = %d)\\n",
    (UINT32)mCountdown,
    (UINT32)(mSelection + 1)
    );
  Say (Line);
}
"""
s = s[:old_draw_start] + new_draw + s[old_draw_end:]

# forward declaration: ActivateSelection uses DrawMenu before it is defined
s = s.replace(
    'STATIC\nVOID\nPrintDeviceInfo (\n  VOID\n  )\n{',
    'STATIC\nVOID\nDrawMenu (\n  VOID\n  );\n\nSTATIC\nVOID\nPrintDeviceInfo (\n  VOID\n  )\n{',
    1)

# ---------- key handler: move selection, restart countdown ----------
old_key = """    if (Key.ScanCode == 0x01) {          // VOL-UP
      if (mSelection > 0) {
        mSelection--;
      }

      DrawMenu ();
    } else if (Key.ScanCode == 0x02) {   // VOL-DOWN
      if (mSelection < 3) {
        mSelection++;
      }

      DrawMenu ();
    }
"""
new_key = """    if (Key.ScanCode == 0x01) {          // VOL-UP
      if (mSelection > 0) {
        mSelection--;
      }

      mCountdown = ACTION_DELAY_SECONDS;
      DrawMenu ();
    } else if (Key.ScanCode == 0x02) {   // VOL-DOWN
      if (mSelection + 1 < MENU_COUNT) {
        mSelection++;
      }

      mCountdown = ACTION_DELAY_SECONDS;
      DrawMenu ();
    }
"""
assert old_key in s
s = s.replace(old_key, new_key, 1)

# ---------- init countdown before the menu is drawn ----------
old_listen = '  Say ("  listening...\\n");\n  DrawMenu ();\n'
new_listen = ('  Say ("  listening...\\n");\n'
              '  mSelection = 0;\n'
              '  mCountdown = ACTION_DELAY_SECONDS;\n'
              '  DrawMenu ();\n')
assert old_listen in s
s = s.replace(old_listen, new_listen, 1)

# ---------- tick: run the countdown ----------
old_tick = """        AsciiSPrint (Line, sizeof (Line),
                     "\\r  t=%3d s  chain=%a  txtin=%d  keys=%d   ",
                     Alive * 5,"""
new_tick = """        if (mCountdown > 0) {
          mCountdown--;
          if (mCountdown == 0) {
            ActivateSelection ();
          } else {
            DrawMenu ();
          }
        }

        AsciiSPrint (Line, sizeof (Line),
                     "\\r  t=%3d s  chain=%a  txtin=%d  keys=%d   ",
                     Alive,"""
assert old_tick in s
s = s.replace(old_tick, new_tick, 1)

s = s.replace('"\\n  [%3d s] chain: %a\\n", Alive * 5,', '"\\n  [%3d s] chain: %a\\n", Alive,')

p.write_text(s, errors='surrogateescape')
print('VermeerKeyProbeDxe.c: menu actions + 3 s countdown (keys45)')
