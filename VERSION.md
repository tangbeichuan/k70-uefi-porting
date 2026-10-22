# keys163

| item | value |
|---|---|
| image | `K70-keys163-CLEAR-EVTRACE-HALT.img` |
| size | 1798144 B (1.71 MB) |
| sha256 | `acdb90e1df5c0d4ea8673a91c9e1c998382fe6759c374290895cfbc22965125e` |
| built | 2026-10-22 12:40 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys163-CLEAR-EVTRACE-HALT.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys163-CLEAR-EVTRACE-HALT.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.