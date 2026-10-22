# keys151

| item | value |
|---|---|
| image | `K70-keys151-NO-PEI-CHANGE.img` |
| size | 1794048 B (1.71 MB) |
| sha256 | `72249c0b3e9cb1280c9b4134e049e58347ff57761647767ee06bdb106168d6e4` |
| built | 2026-10-22 09:53 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys151-NO-PEI-CHANGE.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys151-NO-PEI-CHANGE.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.