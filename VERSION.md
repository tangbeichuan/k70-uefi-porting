# keys103

| item | value |
|---|---|
| image | `K70-keys103-MENU-VIA-DEBUG.img` |
| size | 1660928 B (1.58 MB) |
| sha256 | `c5facff3554bfc1b346d926cbc5c2bc5901b3eda43b6e0a0ce59e08d5f9f70f8` |
| built | 2026-10-21 21:25 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys103-MENU-VIA-DEBUG.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys103-MENU-VIA-DEBUG.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.