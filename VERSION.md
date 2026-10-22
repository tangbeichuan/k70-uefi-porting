# keys97

| item | value |
|---|---|
| image | `K70-keys97-NO-HALT-SMMU-STUB.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `76d1ad26d159545689a1793a1f50ff000e93dc4de6d7c758538f98b06532c33e` |
| built | 2026-10-21 20:43 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys97-NO-HALT-SMMU-STUB.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys97-NO-HALT-SMMU-STUB.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.