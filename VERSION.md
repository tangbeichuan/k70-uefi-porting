# keys142

| item | value |
|---|---|
| image | `K70-keys142-ACPI-SDT.img` |
| size | 1753088 B (1.67 MB) |
| sha256 | `7c2eccad35f764a74495ba3e56201d92f0fbe21f4abc415ec0a7c6ecd27d834b` |
| built | 2026-10-22 01:26 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys142-ACPI-SDT.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys142-ACPI-SDT.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.