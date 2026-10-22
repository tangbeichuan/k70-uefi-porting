import pathlib, re, sys
g = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/gates.py')
s = g.read_text(encoding='utf-8')

if 'VERMEER_GOP_COMPONENT' not in s:
    constants = '''
VERMEER_GOP_COMPONENT = """
!if $(VERMEER_GOP) == 1
  Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf
!endif
"""

VERMEER_GOP_FDF = """
!if $(VERMEER_GOP) == 1
  INF Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf
!endif
"""

'''
    anchor = 'KEYPROBE_COMPONENT = """'
    s = s.replace(anchor, constants + anchor, 1)

if 'def gop(' not in s:
    helper = '''

def gop(dsc, fdf):
    """Add Silicon/Silicium SimpleFbDxe (EFI_GRAPHICS_OUTPUT_PROTOCOL) under VERMEER_GOP."""
    ensure(dsc, "VERMEER_GOP", "0")
    _add_gated(dsc, fdf, "VERMEER_GOP", VERMEER_GOP_COMPONENT, VERMEER_GOP_FDF, "Vermeer GOP")
    set_gate(dsc, "VERMEER_GOP", "1")

'''
    anchor2 = '\ndef vendor_input(dsc, fdf):'
    s = s.replace(anchor2, helper + anchor2, 1)

# make keyprobe() also enable GOP, so every existing build script gets it for free
old = '''def keyprobe(dsc, fdf):
    _add_gated(dsc, fdf, "VERMEER_KEYPROBE", KEYPROBE_COMPONENT, KEYPROBE_FDF,
               "VermeerKeyProbeDxe")'''
new = '''def keyprobe(dsc, fdf):
    _add_gated(dsc, fdf, "VERMEER_KEYPROBE", KEYPROBE_COMPONENT, KEYPROBE_FDF,
               "VermeerKeyProbeDxe")
    # keys111: bring GOP in through the same idempotent plumbing (survives pristine restore)
    gop(dsc, fdf)'''
if old in s:
    s = s.replace(old, new, 1)
    print('keyprobe -> also calls gop: True')
else:
    print('WARN: keyprobe body not matched')

if 'cmd == "gop"' not in s:
    s = s.replace('    elif cmd == "qemu":', '    elif cmd == "gop":\n        gop(sys.argv[2], sys.argv[3])\n    elif cmd == "qemu":', 1)

g.write_text(s, encoding='utf-8')
print('gates.py: has GOP constants =', 'VERMEER_GOP_COMPONENT' in s, '| has gop() =', 'def gop(' in s)