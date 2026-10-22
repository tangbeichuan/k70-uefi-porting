# keys96

| item | value |
|---|---|
| image | `K70-keys96-SMMU-STUB-FOR-UFSDXE.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `8d23d99290a2fbad2faab338c58a7f6ce59314bff37ad8c6b4d7893b9a128a87` |
| built | 2026-10-21 20:39 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys96-SMMU-STUB-FOR-UFSDXE.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys96-SMMU-STUB-FOR-UFSDXE.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.