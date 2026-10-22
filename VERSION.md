# keys153

| item | value |
|---|---|
| image | `K70-keys153-REPACK-BASELINE.img` |
| size | 1794048 B (1.71 MB) |
| sha256 | `d8784724add3a60007cbd887eb719455b1144172667c7feaec224d8ade19f744` |
| built | 2026-10-22 09:59 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys153-REPACK-BASELINE.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys153-REPACK-BASELINE.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.