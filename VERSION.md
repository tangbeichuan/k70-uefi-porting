# keys165

| item | value |
|---|---|
| image | `K70-keys165-REPLUG-EP0.img` |
| size | 1796096 B (1.71 MB) |
| sha256 | `42c004c8e66bfcbe7a605e9f40532e371128e5c3c43b6dec843d85e8b3d943fe` |
| built | 2026-10-22 12:48 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys165-REPLUG-EP0.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys165-REPLUG-EP0.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.