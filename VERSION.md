# keys152b

| item | value |
|---|---|
| image | `K70-keys152b-NO-DUMP.img` |
| size | 1792000 B (1.71 MB) |
| sha256 | `75b00c433a299ec22f7d520fc91803c728343efb4221b3c1b61904818871967d` |
| built | 2026-10-22 10:22 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys152b-NO-DUMP.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys152b-NO-DUMP.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.