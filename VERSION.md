# keys100

| item | value |
|---|---|
| image | `K70-keys100-EMBEDDED-APP-LAUNCH.img` |
| size | 1759232 B (1.68 MB) |
| sha256 | `dbae09c87f9488d7c7318dadc281b437dbea218eefa0afe5fc3b384bf6228634` |
| built | 2026-10-21 21:05 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys100-EMBEDDED-APP-LAUNCH.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys100-EMBEDDED-APP-LAUNCH.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.