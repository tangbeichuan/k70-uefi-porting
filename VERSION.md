# keys99

| item | value |
|---|---|
| image | `K70-keys99-PROBE-RETURNS-UFSDXE-RUNS.img` |
| size | 1757184 B (1.68 MB) |
| sha256 | `7737d2965f3b1e2ac0631f16e488be021bcf6bbe590493d2eca44fa9085bd48a` |
| built | 2026-10-21 20:57 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys99-PROBE-RETURNS-UFSDXE-RUNS.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys99-PROBE-RETURNS-UFSDXE-RUNS.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.