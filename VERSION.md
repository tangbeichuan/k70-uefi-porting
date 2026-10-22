# keys140

| item | value |
|---|---|
| image | `K70-keys140-PMIC-RESTORED.img` |
| size | 1728512 B (1.65 MB) |
| sha256 | `1151b659950c1e607094a425a06764e0dca84383876538d3ced73007e179e5a3` |
| built | 2026-10-22 00:59 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys140-PMIC-RESTORED.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys140-PMIC-RESTORED.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.