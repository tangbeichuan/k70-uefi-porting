# keys146

| item | value |
|---|---|
| image | `K70-keys146-NO-IOMMU-INIT.img` |
| size | 1796096 B (1.71 MB) |
| sha256 | `fefa1c2e24942bbc7e9bc77bf2d462b92aa1e1a300b1bb03c80420bffdd99661` |
| built | 2026-10-22 02:11 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys146-NO-IOMMU-INIT.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys146-NO-IOMMU-INIT.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.