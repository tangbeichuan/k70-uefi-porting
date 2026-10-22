# keys92

| item | value |
|---|---|
| image | `K70-keys92-UFS-IN-CRYPTO-WINDOW.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `9e338013f9e0f594b2445b7b1208e8a7c48bf1823fdd1806821b9daecf691936` |
| built | 2026-10-21 20:10 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys92-UFS-IN-CRYPTO-WINDOW.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys92-UFS-IN-CRYPTO-WINDOW.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.