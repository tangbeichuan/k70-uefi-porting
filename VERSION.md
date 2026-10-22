# keys93

| item | value |
|---|---|
| image | `K70-keys93-UFS-GCC-MAPPED.img` |
| size | 1761280 B (1.68 MB) |
| sha256 | `8a6a92193b4d1d1885a5cdef7dc0b2a56d84c5c605db4520217365da4c42e2ad` |
| built | 2026-10-21 20:14 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys93-UFS-GCC-MAPPED.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys93-UFS-GCC-MAPPED.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.