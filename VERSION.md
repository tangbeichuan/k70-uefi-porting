# keys70

| item | value |
|---|---|
| image | `K70-keys70-CONTROL-BOOTS-TO-MENU.img` |
| size | 1646592 B (1.57 MB) |
| sha256 | `371e14d5adced4e933dd63232636e2f860e62281ace19a54104104e32f186d5a` |
| built | 2026-10-21 17:23 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys70-CONTROL-BOOTS-TO-MENU.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys70-CONTROL-BOOTS-TO-MENU.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.