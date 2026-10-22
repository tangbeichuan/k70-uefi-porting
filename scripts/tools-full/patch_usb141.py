#!/usr/bin/env python3
"""keys141: make UsbConfigDxe actually land in the FV and fix APRIORI dispatch order.

1) Include/DXE.inc is the authoritative FV placement list for [FV.FVMain].
   The keys14x DROP step comments out every "INF Binaries/vermeer..." line whose
   token is in the DROP list (which contains "usbconfig"), and patch_usb130.py
   only un-comments APRIORI.inc.  => UsbConfigDxe had dispatch order but no FV
   image.  Un-comment its DXE.inc line.
2) APRIORI.inc: enforce dispatch order
       VermeerPmicVerStubDxe -> UsbConfigDxe -> UsbInitDxe -> UsbMsdDxe
   (stub already inserted before UsbConfigDxe by patch_pmicstub127.py; here we
   move UsbMsdDxe after UsbConfigDxe and add UsbInitDxe into the block).
"""
import re
import sys

PKG = "/root/k70/uefi/Platforms/Xiaomi/vermeerPkg"
DXE = PKG + "/Include/DXE.inc"
APRIORI = PKG + "/Include/APRIORI.inc"

DROP_RE = re.compile(r"^#\s*\[keys?\d*-drop\]\s*(INF\s+\S+)\s*$")


def read_lines(path):
    with open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
        return f.read().split("\n")


def write_lines(path, lines):
    with open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write("\n".join(lines))


def find_active(lines, needle):
    for i, ln in enumerate(lines):
        s = ln.strip()
        if s.startswith("INF ") and needle in s:
            return i
    return -1


def find_any(lines, needle):
    for i, ln in enumerate(lines):
        s = ln.strip()
        if (s.startswith("INF ") or s.startswith("#")) and needle in s:
            return i
    return -1


def gate_block(lines, idx):
    """Return (start, end_exclusive) of the !if/!endif pair enclosing lines[idx]
    (innermost pair)."""
    start = idx
    while start > 0 and not lines[start].strip().lower().startswith("!if"):
        start -= 1
    end = idx
    while end < len(lines) - 1 and not lines[end].strip().lower().startswith("!endif"):
        end += 1
    return start, end + 1


# ---------------- step 1: DXE.inc placement ----------------
dxe = read_lines(DXE)
changed = 0
for i, ln in enumerate(dxe):
    m = DROP_RE.match(ln.strip())
    if m and "UsbConfigDxe" in m.group(1):
        dxe[i] = "  " + m.group(1)
        changed += 1
        print("[DXE.inc] un-dropped line %d: %s" % (i + 1, dxe[i].strip()))
if find_active(dxe, "UsbConfigDxe/UsbConfigDxe.inf") < 0:
    # fallback: insert after UsbMsdDxe placement, else after UsbInitDxe
    anchor = find_active(dxe, "UsbMsdDxe/UsbMsdDxe.inf")
    if anchor < 0:
        anchor = find_active(dxe, "UsbInitDxe/UsbInitDxe.inf")
    if anchor < 0:
        sys.exit("[DXE.inc] FATAL: no anchor and no UsbConfigDxe line")
    dxe.insert(anchor + 1, "  INF Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.inf")
    print("[DXE.inc] inserted UsbConfigDxe line after line %d" % (anchor + 1))
    changed += 1
write_lines(DXE, dxe)
print("[DXE.inc] changed lines: %d" % changed)

# ---------------- step 2: APRIORI.inc order ----------------
ap = read_lines(APRIORI)

i_stub = find_active(ap, "VermeerPmicVerStubDxe/VermeerPmicVerStubDxe.inf")
i_cfg = find_active(ap, "UsbConfigDxe/UsbConfigDxe.inf")
i_msd = find_active(ap, "UsbMsdDxe/UsbMsdDxe.inf")
i_init = find_active(ap, "UsbInitDxe/UsbInitDxe.inf")
print("[APRIORI.inc] stub=%d cfg=%d msd=%d init=%d" %
      (i_stub + 1, i_cfg + 1, i_msd + 1, i_init + 1))

if i_cfg < 0:
    sys.exit("[APRIORI.inc] FATAL: UsbConfigDxe not active in APRIORI (patch_usb130 must run first)")

# Delete the cfg / msd / init INF lines themselves (keep their gate pairs; the
# patch_pmicstub127 stub lives inside the pair that used to wrap UsbConfigDxe),
# then insert the three lines right after the stub line, in dispatch order.
cfg_line = ap[i_cfg]
msd_line = ap[i_msd] if i_msd >= 0 else "  INF Binaries/vermeer/QcomPkg/Drivers/UsbMsdDxe/UsbMsdDxe.inf"
init_line = ap[i_init] if i_init >= 0 else "  INF Binaries/vermeer/QcomPkg/Drivers/UsbInitDxe/UsbInitDxe.inf"
removals = sorted([x for x in (i_cfg, i_msd, i_init) if x >= 0], reverse=True)
for x in removals:
    print("[APRIORI.inc] removing line %d: %s" % (x + 1, ap[x].strip()))
    del ap[x]

# re-locate stub (indices shifted)
i_stub = find_active(ap, "VermeerPmicVerStubDxe/VermeerPmicVerStubDxe.inf")
if i_stub < 0:
    sys.exit("[APRIORI.inc] FATAL: stub line lost")
insert_at = i_stub + 1
ap[insert_at:insert_at] = [cfg_line, init_line, msd_line]
print("[APRIORI.inc] inserted UsbConfig/UsbInit/UsbMsd at line %d (right after stub)" % (insert_at + 1))
write_lines(APRIORI, ap)

# ---------------- verify ----------------
print()
print("=== verify DXE.inc ===")
for i, ln in enumerate(read_lines(DXE)):
    if "UsbConfigDxe" in ln:
        print("  %d: %s" % (i + 1, ln))
print("=== verify APRIORI.inc order ===")
ap2 = read_lines(APRIORI)
order = {}
for i, ln in enumerate(ap2):
    for name, needle in (("stub", "VermeerPmicVerStubDxe/VermeerPmicVerStubDxe.inf"),
                         ("cfg", "UsbConfigDxe/UsbConfigDxe.inf"),
                         ("init", "UsbInitDxe/UsbInitDxe.inf"),
                         ("msd", "UsbMsdDxe/UsbMsdDxe.inf")):
        if ln.strip().startswith("INF ") and needle in ln:
            order.setdefault(name, i + 1)
            print("  %-5s line %d: %s" % (name, i + 1, ln.strip()))
seq = [(order.get(k, 0), k) for k in ("stub", "cfg", "init", "msd")]
print("  order:", [k for _, k in sorted(x for x in seq if x[0])])
if not (0 < order.get("stub", 0) < order.get("cfg", 0) < order.get("init", 0) < order.get("msd", 0)):
    sys.exit("[APRIORI.inc] FATAL: dispatch order not stub<cfg<init<msd")
print("PATCH_USB141 OK")
