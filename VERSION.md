# keys147d

| item | value |
|---|---|
| image | `K70-keys147d-USBDIAG.img` |
| size | 1796096 B (1.71 MB) |
| sha256 | `22d1d32a9a75b34ca30f9f0e2f96415fa1eaa0f19806cea9314204f25ce35f2b` |
| built | 2026-10-22 02:32 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys147d-USBDIAG.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys147d-USBDIAG.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.