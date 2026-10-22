# keys164

| item | value |
|---|---|
| image | `K70-keys164-EP0-TRACE-HALT.img` |
| size | 1796096 B (1.71 MB) |
| sha256 | `493211b646e9d086fb5106fdc5e5f7bc75e757c9dd7ffb5220420cc98a40afe3` |
| built | 2026-10-22 12:43 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys164-EP0-TRACE-HALT.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys164-EP0-TRACE-HALT.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.