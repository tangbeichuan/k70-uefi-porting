# keys102

| item | value |
|---|---|
| image | `K70-keys102-MENU-DIAG.img` |
| size | 1660928 B (1.58 MB) |
| sha256 | `ed4412c8ae6b2aff42fa1b509e0b166c56004c242c7dc9454dbf7800f2f2323d` |
| built | 2026-10-21 21:21 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys102-MENU-DIAG.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys102-MENU-DIAG.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.