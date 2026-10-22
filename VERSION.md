# keys90

| item | value |
|---|---|
| image | `K70-keys90-UFS-GCC-OCS.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `fafab65b04b6592797305b043df09b7c8a33a859d996f9d4c187d24cc64e01ce` |
| built | 2026-10-21 20:01 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys90-UFS-GCC-OCS.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys90-UFS-GCC-OCS.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.