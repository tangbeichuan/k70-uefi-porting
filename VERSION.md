# keys161b

| item | value |
|---|---|
| image | `K70-keys161b-MINIMAL-WRITE.img` |
| size | 1800192 B (1.72 MB) |
| sha256 | `8c6095d4c12383418e64c7de9f1516f0da77f35c0ecdbbb0d31bff607fec593b` |
| built | 2026-10-22 12:23 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys161b-MINIMAL-WRITE.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys161b-MINIMAL-WRITE.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.