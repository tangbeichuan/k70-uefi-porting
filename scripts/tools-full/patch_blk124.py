import pathlib
p = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = p.read_text(encoding="utf-8", errors="surrogateescape")

if "Protocol/BlockIo.h" not in s:
    s = s.replace('#include <Protocol/GraphicsOutput.h>',
                  '#include <Protocol/GraphicsOutput.h>\n#include <Protocol/BlockIo.h>   // keys124: block device counter', 1)

old_decl = "  CHAR8        KeyLine[64];          // keys119"
if "KeyLine2" not in s:
    s = s.replace(old_decl, old_decl + "\n  CHAR8        KeyLine2[64];         // keys124", 1)

anchor = '      GuiText (KeyLine, 60, 1460, 2, 0x00FFD070, 0x00101820);'
add = anchor + '''
      // keys124: show how many block devices exist (our log disk shows up here)
      {
        UINTN       BlkCount = 0;
        EFI_HANDLE *BlkBuf   = NULL;

        if (EFI_ERROR (gBS->LocateHandleBuffer (ByProtocol, &gEfiBlockIoProtocolGuid,
                                                NULL, &BlkCount, &BlkBuf))) {
          BlkCount = 0;
        }
        if (BlkBuf != NULL) {
          gBS->FreePool (BlkBuf);
        }
        AsciiSPrint (KeyLine2, sizeof (KeyLine2), "BlockIO devices: %d", (UINT32)BlkCount);
        GuiText (KeyLine2, 60, 1510, 2, 0x00A0E0A0, 0x00101820);
      }'''
if "BlockIO devices:" not in s:
    assert anchor in s, "anchor not found"
    s = s.replace(anchor, add, 1)

p.write_text(s, encoding="utf-8", errors="surrogateescape")
print("menu patched ok")