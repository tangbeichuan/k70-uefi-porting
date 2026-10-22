# keys151b

| item | value |
|---|---|
| image | `K70-keys151b-USBROW-REMOVED.img` |
| size | 1794048 B (1.71 MB) |
| sha256 | `84841bc96d0252fbc4018c60885d7d902ec41f30278be7cf0d43233e60fdbd2a` |
| built | 2026-10-22 09:53 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys151b-USBROW-REMOVED.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys151b-USBROW-REMOVED.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.