# keys95

| item | value |
|---|---|
| image | `K70-keys95-SMMU-DIAG.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `04d8e819c344ea5c1f964ba074a36edff2bbfa1fca2c6bf8ead986c58df620d3` |
| built | 2026-10-21 20:24 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys95-SMMU-DIAG.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys95-SMMU-DIAG.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.