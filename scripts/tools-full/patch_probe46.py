import pathlib

p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(errors='surrogateescape')

# only start counting down after a key; otherwise the menu re-draws itself forever
s = s.replace('  mSelection = 0;\n  mCountdown = ACTION_DELAY_SECONDS;\n  DrawMenu ();',
              '  mSelection = 0;\n  mCountdown = 0;\n  DrawMenu ();', 1)

s = s.replace("""  mCountdown = ACTION_DELAY_SECONDS;
  DrawMenu ();
}

STATIC
VOID
DrawMenu (""", """  mCountdown = 0;
  DrawMenu ();
}

STATIC
VOID
DrawMenu (""", 1)

old_tail = """  AsciiSPrint (
    Line,
    sizeof (Line),
    "  [UI]  VOL-UP/DOWN = move, otherwise it acts in %d s (selected = %d)\\n",
    (UINT32)mCountdown,
    (UINT32)(mSelection + 1)
    );
  Say (Line);"""
new_tail = """  if (mCountdown > 0) {
    AsciiSPrint (
      Line,
      sizeof (Line),
      "  [UI]  acts in %d s unless you press a volume key (selected = %d)\\n",
      (UINT32)mCountdown,
      (UINT32)(mSelection + 1)
      );
  } else {
    AsciiSPrint (
      Line,
      sizeof (Line),
      "  [UI]  VOL-UP / VOL-DOWN to move; it acts 3 s after the last key (selected = %d)\\n",
      (UINT32)(mSelection + 1)
      );
  }

  Say (Line);"""
assert old_tail in s
s = s.replace(old_tail, new_tail, 1)

p.write_text(s, errors='surrogateescape')
print('keys46: countdown only after a key press')
