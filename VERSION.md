# keys88

| item | value |
|---|---|
| image | `K70-keys88-UFS-EARLY-HALT.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `b5013c0e594cdeef2b0ce84d92d18f8443a04ac4fd40b68324207b8aa4dcf023` |
| built | 2026-10-21 19:56 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys88-UFS-EARLY-HALT.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys88-UFS-EARLY-HALT.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.