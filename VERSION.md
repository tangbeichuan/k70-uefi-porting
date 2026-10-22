# keys161

| item | value |
|---|---|
| image | `K70-keys161-NO-SOFTRESET.img` |
| size | 1800192 B (1.72 MB) |
| sha256 | `ccf2cceb43734c9a0e1b02e832fa46ef8a03b3f38c4fd26701e6d3224656dbb9` |
| built | 2026-10-22 12:23 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys161-NO-SOFTRESET.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys161-NO-SOFTRESET.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.