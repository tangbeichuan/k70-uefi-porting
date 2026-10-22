set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys112' in s:
    print('already patched'); raise SystemExit
# include GOP header
if '#include <Protocol/GraphicsOutput.h>' not in s:
    anchor = '#include <Protocol/SimpleTextIn.h>'
    if anchor in s:
        s = s.replace(anchor, anchor + '\n#include <Protocol/GraphicsOutput.h>  // keys112: GOP probe', 1)
    else:
        s = s.replace('#include <Library/UefiBootServicesTableLib.h>', '#include <Library/UefiBootServicesTableLib.h>\n#include <Protocol/GraphicsOutput.h>  // keys112: GOP probe', 1)
# insert GOP probe right before the ConIn/ConOut print
anchor2 = 'UnicodeSPrint (Line, sizeof (Line), L"  [UI] ConIn=%s ConOut=%s"'
idx = s.find(anchor2)
if idx < 0:
    print('anchor2 not found'); raise SystemExit(2)
probe = (
'  {  // keys112: report GOP (SimpleFbDxe) availability\n'
'    EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop = NULL;\n'
'    EFI_STATUS                     Gst;\n'
'    Gst = gBS->LocateProtocol (&gEfiGraphicsOutputProtocolGuid, NULL, (VOID **)&Gop);\n'
'    if (!EFI_ERROR (Gst) && Gop != NULL && Gop->Mode != NULL && Gop->Mode->Info != NULL) {\n'
'      UnicodeSPrint (Line, sizeof (Line), L"  [UI] GOP=yes %ux%u\\r\\n",\n'
'                     (UINT32)Gop->Mode->Info->HorizontalResolution,\n'
'                     (UINT32)Gop->Mode->Info->VerticalResolution);\n'
'    } else {\n'
'      UnicodeSPrint (Line, sizeof (Line), L"  [UI] GOP=no (%r)\\r\\n", Gst);\n'
'    }\n'
'    ConOut (Line);\n'
'  }\n'
)
# find the start of the line containing anchor2
line_start = s.rfind('\n', 0, idx) + 1
s = s[:line_start] + probe + s[line_start:]
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('GOP probe inserted')
PY
grep -n "keys112" "$F" | head