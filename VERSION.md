# keys155

| item | value |
|---|---|
| image | `K70-keys155-GCC-READ.img` |
| size | 1794048 B (1.71 MB) |
| sha256 | `c376c20c8f6975fe0fa0c34b0bc27413838fa7a3421e8edef966f343c36fb49a` |
| built | 2026-10-22 10:49 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys155-GCC-READ.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys155-GCC-READ.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.