# keys159

| item | value |
|---|---|
| image | `K70-keys159-EP0-MINIMAL.img` |
| size | 1800192 B (1.72 MB) |
| sha256 | `b2a2289be93aa98866167bc3ad11a080161ef65cd28330a92fd0a9fa44591c0e` |
| built | 2026-10-22 11:58 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys159-EP0-MINIMAL.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys159-EP0-MINIMAL.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.