# keys86

| item | value |
|---|---|
| image | `K70-keys86-HALIOMMU-BACK-UFSMAP.img` |
| size | 1771520 B (1.69 MB) |
| sha256 | `1ed107ee0a82deb10495223493479024e67448ad14d45e0a444955750ab2a8da` |
| built | 2026-10-21 19:41 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys86-HALIOMMU-BACK-UFSMAP.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys86-HALIOMMU-BACK-UFSMAP.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.