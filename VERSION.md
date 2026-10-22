# keys106

| item | value |
|---|---|
| image | `K70-keys106-LINKUP-CHECK.img` |
| size | 1665024 B (1.59 MB) |
| sha256 | `123bdba6674948c98f3fd0e155b1267cf469bf3dbf8b283815038568c0822086` |
| built | 2026-10-21 21:51 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys106-LINKUP-CHECK.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys106-LINKUP-CHECK.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.