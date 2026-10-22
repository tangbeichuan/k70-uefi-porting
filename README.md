# source/vermeer-platform

Complete platform package source for Redmi K70 (vermeer / SM8550):
`Platforms/Xiaomi/vermeerPkg/` -- 40 files (dsc, fdf, APRIORI/DXE/RAW includes,
MemoryMapLib, and 11 self-written DXE drivers under `Drivers/Vermeer*`).

Origin: local build tree `/root/k70/uefi/Platforms/Xiaomi/vermeerPkg`
(derived from Mu-Silicium's vermeerPkg).

## Usage

    git clone -b source/vermeer-platform https://github.com/tangbeichuan/k70-uefi-porting.git vermeer-src
    cp -a vermeer-src/vermeerPkg  <Mu-Silicium>/Platforms/Xiaomi/

Then follow the 4-step build guide in the `main` branch README.

## Key files

- `vermeer.dsc` / `vermeer.fdf` : platform description, FV layout, feature gates
- `Include/APRIORI.inc` : DXE dispatch order (our drivers are inserted here)
- `Include/DXE.inc` / `Include/RAW.inc`
- `Library/MemoryMapLib/MemoryMapLib.c` : memory map (UFS/GCC/USB MMIO windows)
- `Drivers/Vermeer*` : 11 self-written drivers

Only the platform package is included here; the rest of upstream Mu-Silicium is not
(1.4 GB, unmodified).