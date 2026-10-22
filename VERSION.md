# keys141

| item | value |
|---|---|
| image | `K70-keys141-USB-CONFIG.img` |
| size | 1744896 B (1.66 MB) |
| sha256 | `a66b1a6385dcc544b03af6e6593e117f41b6c1302a23e2be4c9bd77cccc59a9c` |
| built | 2026-10-22 01:17 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys141-USB-CONFIG.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys141-USB-CONFIG.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.