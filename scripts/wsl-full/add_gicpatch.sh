#!/usr/bin/env bash
# sheng needs Gic-Spurious.patch on Qualcomm (a level-triggered interrupt with no
# handler spins forever, e.g. residual IPCC INTID 0x105). build_uefi.py only
# applies five patches, so add this one to both the apply and the revert list.
set -e
python3 - <<'PY'
p = "/root/k70/uefi/build_uefi.py"
src = open(p, encoding="utf-8").read()
old = '"Usb-Bus.patch"]:'
new = '"Usb-Bus.patch",\n                      "Gic-Spurious.patch"]:'
n = src.count(old)
if n == 0:
    print("already patched or pattern changed")
else:
    src = src.replace(old, new)
    open(p, "w", encoding="utf-8", newline="\n").write(src)
    print(f"patched {n} patch list(s)")
PY
grep -n 'Gic-Spurious' /root/k70/uefi/build_uefi.py
