# keys84

| item | value |
|---|---|
| image | `K70-keys84-UFS-MAP-RUNTIME.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `ef20bf3a3f2a4d54333bb33572c858f8dab02c31b923c6a96e1fa1bfa8f9916e` |
| built | 2026-10-21 19:35 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys84-UFS-MAP-RUNTIME.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys84-UFS-MAP-RUNTIME.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.