# keys162

| item | value |
|---|---|
| image | `K70-keys162-EVTRACE-ONLY.img` |
| size | 1798144 B (1.71 MB) |
| sha256 | `c3204d4763c1ad661ca83a7db2663c2b2f34b5515ea6cf016e2d09df6e02f99a` |
| built | 2026-10-22 12:29 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys162-EVTRACE-ONLY.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys162-EVTRACE-ONLY.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.