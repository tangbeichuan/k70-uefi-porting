# keys154

| item | value |
|---|---|
| image | `K70-keys154-USB-RUN.img` |
| size | 1794048 B (1.71 MB) |
| sha256 | `37cce641682af39f6abc2a7ddcd7d9aee49094cd1c9eadca5a47b42c36921155` |
| built | 2026-10-22 10:21 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys154-USB-RUN.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys154-USB-RUN.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.