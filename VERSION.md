# keys157

| item | value |
|---|---|
| image | `K70-keys157-EARLY-USB-RUN.img` |
| size | 1798144 B (1.71 MB) |
| sha256 | `8ddc2f588bff0d62a7966aa58b26c3d141cd4b71797327f7df91052f8b633756` |
| built | 2026-10-22 11:39 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys157-EARLY-USB-RUN.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys157-EARLY-USB-RUN.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.