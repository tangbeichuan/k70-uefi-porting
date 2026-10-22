# keys158

| item | value |
|---|---|
| image | `K70-keys158-DEVTEN-CLEAR.img` |
| size | 1798144 B (1.71 MB) |
| sha256 | `2cc5a7404d7d8c80fc492b3c3ecee6958cd685bc983c5a2003e7f7f3b23d76d0` |
| built | 2026-10-22 11:53 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys158-DEVTEN-CLEAR.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys158-DEVTEN-CLEAR.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.