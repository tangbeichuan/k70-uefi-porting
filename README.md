# source/upstream-patches

All modifications we made to upstream Mu-Silicium files (6 files + `vermeer.patch`, 156 lines).

| File | Why |
|---|---|
| `BootShim/BootShim.S` / `Makefile` | 4 MiB FD support, marker paint, FD_BASE/FD_SIZE parameterized |
| `Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c` | disable scheduler/FV-list HOB path that crashed; optional DTB-Ext HOB suppression |
| `Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFb.c` | instrumentation + frame-buffer probe for GOP (Display Reserved 0xB8000000) |
| `build_uefi.py` | FD size / packaging adjustments |
| `Resources/Configs/vermeer.toml` | `[uefi_fd] size = 0x400000` and platform options |

## Apply

    cd <Mu-Silicium>
    git apply /path/to/vermeer.patch