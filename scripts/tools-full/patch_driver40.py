import pathlib

p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.c')
raw = p.read_bytes().decode('gbk')
s = raw.replace('\r\n', '\n').replace('\r', '\n')

if 'keys40' in s:
    print('already patched')
    raise SystemExit

old = '''    DumpConfigTables ();
    InteractiveDemo ();
  }'''
new = '''    DumpConfigTables ();
    //
    // keys40: InteractiveDemo() must NOT run here.  It blocks in ReadKeyStroke before
    // ConSplitter/GraphicsConsole exist, which is exactly why keys38/39 showed only the garbled
    // one-shot line and no tick.  The interactive part is the periodic timer below.
    //
  }'''
assert s.count(old) == 1, s.count(old)
s = s.replace(old, new, 1)

# keep InteractiveDemo referenced from the never-taken branch
old_dead = '''    if (mLegacyProbe == 2) {
      ProbeShimFdt ();'''
new_dead = '''    if (mLegacyProbe == 2) {
      InteractiveDemo ();
      ProbeShimFdt ();'''
assert old_dead in s
s = s.replace(old_dead, new_dead, 1)

p.write_bytes(s.replace('\n', '\r\n').encode('gbk'))
print('keys40 patch applied')
