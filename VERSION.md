# keys167

| item | value |
|---|---|
| image | `K70-keys167-EP0-DESC.img` |
| size | 1796096 B (1.71 MB) |
| sha256 | `49a6f8774f4e3fb523098b7cb12035b4ded6284bfdd7cebe2fe2e3da71e55cda` |
| built | 2026-10-22 13:52 |
| download | https://github.com/tangbeichuan/k70-uefi-porting/releases/download/v0.1.0-milestones/K70-keys167-EP0-DESC.img |

## Run (memory boot, no partition writes)

    fastboot boot K70-keys167-EP0-DESC.img

## Notes

- One of the keys0 -> keys168 iterations. Details and on-screen readings:
  `docs/10-真机实验完整记录.md` and `docs/reports/` on the `main` branch.
- Driver sources: `drivers/` (main) and `source/vermeer-platform` branch.