# keys91

| item | value |
|---|---|
| image | `K70-keys91-PEI-UFS-MAP.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `f368875c4afd76e172db9289a6ce0a8e9015e9f16902da5e5907d046720a17ac` |
| built | 2026-10-21 20:06 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys91-PEI-UFS-MAP.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys91-PEI-UFS-MAP.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.