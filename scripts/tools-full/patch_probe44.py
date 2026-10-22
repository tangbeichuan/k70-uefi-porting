import pathlib

p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(errors='surrogateescape')

# ---- 1. menu state + DrawMenu(), inserted right after Say() ----
anchor_say_end = """    gST->ConOut->OutputString (gST->ConOut, Wide);
  }
}
"""
menu_block = anchor_say_end + """
/**
  The three-line menu shown on the panel.  It exists to prove that this firmware can be
  *operated* with the volume keys, not just that it prints.
**/
STATIC CONST CHAR8 *mMenuItems[4] = {
  "Boot Linux (UFS)",
  "Boot UniXNU",
  "Device information",
  "Reboot / power off"
};

STATIC UINTN  mSelection = 0;

STATIC
VOID
DrawMenu (
  VOID
  )
{
  CHAR8  Line[128];
  UINTN  Index;

  Say ("\\n  [UI] ==== Vermeer UEFI menu ====\\n");
  for (Index = 0; Index < 4; Index++) {
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
    "  [UI]  VOL-UP = up, VOL-DOWN = down, selected = %d\\n",
    (UINT32)(mSelection + 1)
    );
  Say (Line);
}
"""
assert anchor_say_end in s, 'Say() anchor missing'
s = s.replace(anchor_say_end, menu_block, 1)

# ---- 2. drive the menu from the volume keys ----
anchor_key = """    Say (Line);
    Got = TRUE;
  }

  return Got;
"""
new_key = """    Say (Line);

    if (Key.ScanCode == 0x01) {          // VOL-UP
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

    Got = TRUE;
  }

  return Got;
"""
assert anchor_key in s, 'DrainTextIn anchor missing'
s = s.replace(anchor_key, new_key, 1)

# ---- 3. draw it once when the console is up ----
anchor_listen = '  Say ("  listening...\\n");\n'
assert anchor_listen in s, 'listening anchor missing'
s = s.replace(anchor_listen, anchor_listen + '  DrawMenu ();\n', 1)

p.write_text(s, errors='surrogateescape')
print('VermeerKeyProbeDxe.c: volume-key menu added')
