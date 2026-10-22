# keys160

| item | value |
|---|---|
| image | `K70-keys160-EVTRACE.img` |
| size | 1800192 B (1.72 MB) |
| sha256 | `aa7d64e81c502ccd1161e4952fb8e32e08c41ccee6ab69af75adada54169f863` |
| built | 2026-10-22 12:17 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys160-EVTRACE.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys160-EVTRACE.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.