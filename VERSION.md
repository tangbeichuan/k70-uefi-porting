# keys152

| item | value |
|---|---|
| image | `K70-keys152-MINIMAL-MENU.img` |
| size | 1794048 B (1.71 MB) |
| sha256 | `0f0be4f2f3148192710893206a78ab0984dda1c2641db5c4f71c486bc9fff942` |
| built | 2026-10-22 10:02 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys152-MINIMAL-MENU.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys152-MINIMAL-MENU.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.