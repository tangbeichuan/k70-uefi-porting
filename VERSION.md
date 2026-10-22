# keys145

| item | value |
|---|---|
| image | `K70-keys145-IOMMU-GUARD.img` |
| size | 1796096 B (1.71 MB) |
| sha256 | `7660a804a85d82211cf096fe0f8056c9c1ba6ea835a1823bc4e1688dc9a24f6b` |
| built | 2026-10-22 01:53 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys145-IOMMU-GUARD.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys145-IOMMU-GUARD.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.