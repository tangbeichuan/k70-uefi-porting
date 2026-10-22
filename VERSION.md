# keys143

| item | value |
|---|---|
| image | `K70-keys143-USB-CONFIG-2.img` |
| size | 1763328 B (1.68 MB) |
| sha256 | `c1dc3baef6701062688abcb80f8bba1fda663d22455e73a73fe69efc0cae6fdd` |
| built | 2026-10-22 01:37 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys143-USB-CONFIG-2.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys143-USB-CONFIG-2.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.