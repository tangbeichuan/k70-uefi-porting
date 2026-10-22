# keys83

| item | value |
|---|---|
| image | `K70-keys83-42REGIONS-NO-MAPCHANGE.img` |
| size | 1658880 B (1.58 MB) |
| sha256 | `29ba76cf922f0311be0e1fc19728ef84262af71a56bca3a412a925e285f99469` |
| built | 2026-10-21 19:28 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys83-42REGIONS-NO-MAPCHANGE.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys83-42REGIONS-NO-MAPCHANGE.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.