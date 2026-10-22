# keys144

| item | value |
|---|---|
| image | `K70-keys144-CLOCKDXE.img` |
| size | 1787904 B (1.71 MB) |
| sha256 | `d34e629425ff6ec0a811b6a07342e44c0190192182b8738fb0d4301b3d4ae08e` |
| built | 2026-10-22 01:42 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys144-CLOCKDXE.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys144-CLOCKDXE.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.