# keys112

| item | value |
|---|---|
| image | `K70-keys112-GOP-PROBE.img` |
| size | 1665024 B (1.59 MB) |
| sha256 | `3002dc646c466df205bb30d9a5d82a4a74dff0cb51bcafd1135b0f83b4cd43e9` |
| built | 2026-10-21 22:32 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys112-GOP-PROBE.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys112-GOP-PROBE.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.