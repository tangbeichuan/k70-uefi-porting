# keys94

| item | value |
|---|---|
| image | `K70-keys94-DOORBELL-REACHED.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `d2aa26deb335ade1516a675e73a9b8656b2b5165d7e42c082cceedc7b8d4efe0` |
| built | 2026-10-21 20:18 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys94-DOORBELL-REACHED.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys94-DOORBELL-REACHED.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.