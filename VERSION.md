# keys89

| item | value |
|---|---|
| image | `K70-keys89-UFS-MAP-IN-PROBE.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `54e9a2a113f9a7bcb2c9e301418a0c55ac8abb60a9d342401c9b7eb9ea5aa25d` |
| built | 2026-10-21 19:59 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys89-UFS-MAP-IN-PROBE.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys89-UFS-MAP-IN-PROBE.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.