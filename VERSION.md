# keys168

| item | value |
|---|---|
| image | `K70-keys168-CONSOLE-MARKERS.img` |
| size | 1796096 B (1.71 MB) |
| sha256 | `5a02510d4d2fa93c65ac5f40e306995510daff62c0bb0f481ecaee4d1e2fb8db` |
| built | 2026-10-22 14:35 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys168-CONSOLE-MARKERS.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys168-CONSOLE-MARKERS.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.