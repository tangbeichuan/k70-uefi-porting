# keys139

| item | value |
|---|---|
| image | `K70-keys139-PROVIDER-SLOTS.img` |
| size | 1673216 B (1.6 MB) |
| sha256 | `476dd61f07a2065ac121f5ab1fd87ff87af1fc10fd5957c9223dd0f840f38b11` |
| built | 2026-10-22 00:58 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys139-PROVIDER-SLOTS.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys139-PROVIDER-SLOTS.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.