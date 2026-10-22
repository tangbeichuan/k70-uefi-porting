# keys98

| item | value |
|---|---|
| image | `K70-keys98-VENDOR-UFSDXE-ONLY.img` |
| size | 1759232 B (1.68 MB) |
| sha256 | `6eacd941e95dce3fbda9dc58966fac6286542a709c1fbb64ee658553984f488d` |
| built | 2026-10-21 20:48 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys98-VENDOR-UFSDXE-ONLY.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys98-VENDOR-UFSDXE-ONLY.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.