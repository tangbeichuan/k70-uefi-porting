#!/usr/bin/env python3
"""keys142: enable the real ACPI SDT protocol producer (AcpiTableDxe) in the FV.

Why: UsbConfigDxe's depex requires gEfiAcpiSdtProtocolGuid (EB97088E-...),
whose only producer is MdeModulePkg/Universal/Acpi/AcpiTableDxe.  Our
vermeer.fdf has the whole ACPI block commented out, so the depex could never
be satisfied and UsbConfigDxe (producer of E722B03F, required by UsbInitDxe)
never dispatched.

Scope (deliberately minimal, per Lead):
  * uncomment ONLY `INF MdeModulePkg/Universal/Acpi/AcpiTableDxe/AcpiTableDxe.inf`
  * keep AcpiPlatformDxe and the ACPITABLE RuleOverride block commented
  * do not touch the DSC (AcpiTableDxe is already a component via
    Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc:496)

Idempotent: if the line is already active it reports and changes nothing.
"""
import os
import re
import sys

FDF = "/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf"
DSC_INC = "/root/k70/uefi/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc"

TARGET = "MdeModulePkg/Universal/Acpi/AcpiTableDxe/AcpiTableDxe.inf"
RE_COMMENTED = re.compile(r"^(\s*)#\s*INF\s+" + re.escape(TARGET) + r"\s*$")
RE_ACTIVE = re.compile(r"^(\s*)INF\s+" + re.escape(TARGET) + r"\s*$")
FORBIDDEN = [
    "MdeModulePkg/Universal/Acpi/AcpiPlatformDxe/AcpiPlatformDxe.inf",
    "vermeer/AcpiTables.inf",
]


def die(msg):
    print("[patch_acpi142] FATAL: " + msg)
    sys.exit(1)


def main():
    if not os.path.isfile(FDF):
        die("fdf not found: " + FDF)
    lines = open(FDF, "r", encoding="utf-8", errors="surrogateescape").read().splitlines(True)

    hits_active = [i for i, L in enumerate(lines) if RE_ACTIVE.match(L)]
    hits_comm = [i for i, L in enumerate(lines) if RE_COMMENTED.match(L)]

    if hits_active:
        print("[patch_acpi142] already active at fdf line(s): %s (no change)"
              % ",".join(str(i + 1) for i in hits_active))
    elif not hits_comm:
        die("commented AcpiTableDxe line not found in " + FDF)
    else:
        if len(hits_comm) != 1:
            die("expected exactly 1 commented AcpiTableDxe line, found %d" % len(hits_comm))
        i = hits_comm[0]
        lines[i] = "  INF " + TARGET + "\n"
        open(FDF, "w", encoding="utf-8", errors="surrogateescape").write("".join(lines))
        print("[patch_acpi142] enabled AcpiTableDxe at fdf line %d" % (i + 1))

    # re-read and report effective state
    lines = open(FDF, "r", encoding="utf-8", errors="surrogateescape").read().splitlines(True)
    for i, L in enumerate(lines):
        if any(f in L for f in FORBIDDEN):
            if not L.lstrip().startswith("#"):
                die("refusing: '%s' must stay commented (line %d)" % (L.strip(), i + 1))
        if TARGET in L:
            print("[patch_acpi142] fdf:%d = %s" % (i + 1, L.rstrip()))

    # DSC component check (informational, must not be modified)
    if os.path.isfile(DSC_INC):
        txt = open(DSC_INC, "r", encoding="utf-8", errors="surrogateescape").read().splitlines()
        comp = [i + 1 for i, L in enumerate(txt) if TARGET in L and not L.lstrip().startswith("#")]
        if comp:
            print("[patch_acpi142] dsc.inc component present at line %s (unchanged)"
                  % ",".join(map(str, comp)))
        else:
            die("AcpiTableDxe not an active component in " + DSC_INC)
    else:
        die("dsc.inc not found: " + DSC_INC)

    print("PATCH_ACPI142 OK")


if __name__ == "__main__":
    main()
