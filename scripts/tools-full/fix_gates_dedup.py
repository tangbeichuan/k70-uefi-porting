import pathlib
g = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/gates.py')
s = g.read_text(encoding='utf-8')
old = '''def gop(dsc, fdf):
    """Add Silicon/Silicium SimpleFbDxe (EFI_GRAPHICS_OUTPUT_PROTOCOL) under VERMEER_GOP."""
    ensure(dsc, "VERMEER_GOP", "0")
    _add_gated(dsc, fdf, "VERMEER_GOP", VERMEER_GOP_COMPONENT, VERMEER_GOP_FDF, "Vermeer GOP")
    set_gate(dsc, "VERMEER_GOP", "1")'''
new = '''def gop(dsc, fdf):
    """Add SimpleFbDxe (EFI_GRAPHICS_OUTPUT_PROTOCOL) under VERMEER_GOP.

    The FDF block is enough to place the driver in the FV.  Include/APRIORI.inc is pulled
    into the same FV, so a duplicate line there makes GenFv abort with
    "the 54th file and 63th file have the same file GUID".  Strip it from APRIORI.inc.
    """
    ensure(dsc, "VERMEER_GOP", "0")
    _add_gated(dsc, fdf, "VERMEER_GOP", VERMEER_GOP_COMPONENT, VERMEER_GOP_FDF, "Vermeer GOP")
    set_gate(dsc, "VERMEER_GOP", "1")
    apriori = pathlib.Path(fdf).parent / 'Include' / 'APRIORI.inc'
    if apriori.exists():
        txt = apriori.read_text(encoding='utf-8', errors='surrogateescape')
        kept = [ln for ln in txt.splitlines(True) if 'SimpleFbDxe.inf' not in ln]
        if len(kept) != len(txt.splitlines(True)):
            apriori.write_text(''.join(kept), encoding='utf-8', errors='surrogateescape')
            print('   apriori: stripped duplicate SimpleFbDxe line(s)')'''
assert old in s
s = s.replace(old, new, 1)
if 'import pathlib' not in s:
    s = s.replace('import re\nimport sys', 'import pathlib\nimport re\nimport sys', 1)
g.write_text(s, encoding='utf-8')
print('gop() dedup added')