# keys143b

| item | value |
|---|---|
| image | `K70-keys143b-NO-HALIOMMU.img` |
| size | 1753088 B (1.67 MB) |
| sha256 | `8f1c42bb1e1526caaeb5e35cffd231b961c408e50f07b88c6262f79b4d3d6b39` |
| built | 2026-10-22 01:39 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys143b-NO-HALIOMMU.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys143b-NO-HALIOMMU.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.