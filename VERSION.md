# keys87

| item | value |
|---|---|
| image | `K70-keys87-DOORBELL-DIAG.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `3fe2e19c57097ecd20d5dc2a9793efdf55095db6df0873d4ba98fddf0c5b7377` |
| built | 2026-10-21 19:48 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys87-DOORBELL-DIAG.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys87-DOORBELL-DIAG.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.