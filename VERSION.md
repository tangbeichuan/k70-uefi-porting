# keys105

| item | value |
|---|---|
| image | `K70-keys105-KEY-ENUM.img` |
| size | 1662976 B (1.59 MB) |
| sha256 | `6aa8deaf506fff492764fd119241ab0c62af6a7563a4c7e56eec18d59b95979d` |
| built | 2026-10-21 21:36 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys105-KEY-ENUM.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys105-KEY-ENUM.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.