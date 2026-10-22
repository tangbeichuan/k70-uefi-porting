# keys148

| item | value |
|---|---|
| image | `K70-keys148-DWC3-FIX.img` |
| size | 1796096 B (1.71 MB) |
| sha256 | `3355003674f643770c0aaf57ce3de957554e556d9defc317d651f402a13218ec` |
| built | 2026-10-22 02:50 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys148-DWC3-FIX.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys148-DWC3-FIX.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.