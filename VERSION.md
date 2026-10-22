# keys82

| item | value |
|---|---|
| image | `K70-keys82-UFSMAP-NO-PMIC-NO-HALIOMMU.img` |
| size | 1658880 B (1.58 MB) |
| sha256 | `a01becf2f6a6c169521b02ed714c36994c8fd6db2ec4f312a36d43b35a5ecec5` |
| built | 2026-10-21 19:07 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys82-UFSMAP-NO-PMIC-NO-HALIOMMU.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys82-UFSMAP-NO-PMIC-NO-HALIOMMU.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.