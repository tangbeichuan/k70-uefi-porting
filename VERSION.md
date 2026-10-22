# keys121

| item | value |
|---|---|
| image | `K70-keys121-GUI-MENU-FINAL.img` |
| size | 1667072 B (1.59 MB) |
| sha256 | `9046aaec347fb738eeb4d6c129fd780e0d65378a54032910a2eafc9e37692b93` |
| built | 2026-10-21 23:43 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys121-GUI-MENU-FINAL.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys121-GUI-MENU-FINAL.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.