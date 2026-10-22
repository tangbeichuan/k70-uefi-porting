# keys101

| item | value |
|---|---|
| image | `K70-keys101-LATE-MENU-KEYS-WORK.img` |
| size | 1660928 B (1.58 MB) |
| sha256 | `96161d77c1ff6b043360edfedf74d879bd3d060dd4b5cef1d4e22fdcec27a520` |
| built | 2026-10-21 21:18 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys101-LATE-MENU-KEYS-WORK.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys101-LATE-MENU-KEYS-WORK.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.