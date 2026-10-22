# keys104

| item | value |
|---|---|
| image | `K70-keys104-MENU-KEYLOG.img` |
| size | 1660928 B (1.58 MB) |
| sha256 | `81bde2c55caf960ed66ab074ab95ea7138e71d3af1bf34e6a5b7f7b3fd85b7a3` |
| built | 2026-10-21 21:31 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys104-MENU-KEYLOG.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys104-MENU-KEYLOG.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.