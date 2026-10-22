# keys156

| item | value |
|---|---|
| image | `K70-keys156-ALIVE-CHECK.img` |
| size | 1794048 B (1.71 MB) |
| sha256 | `9185fc59675e0c756c241251e643ee93a412312a64c55b22aa135cec39643ddb` |
| built | 2026-10-22 11:13 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys156-ALIVE-CHECK.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys156-ALIVE-CHECK.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.