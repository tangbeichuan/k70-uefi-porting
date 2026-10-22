#!/usr/bin/env python3
"""Idempotent gate plumbing for the vermeer platform description.

The port has three build-time switches that must live in vermeer.dsc [Defines] (putting a
DEFINE anywhere else silently leaves the name undefined, and every `!if $(NAME) == 1` then
evaluates false while the build still reports Success):

    VERMEER_VENDOR_HW   stock Qualcomm DXE stack          (default 0)
    VERMEER_PAINT       frame-buffer telemetry driver     (default 0)
    VERMEER_BANNER      banner + heartbeat driver         (default 0)
    QEMU_BRINGUP        QEMU-only PCDs / MMIO windows      (default 0)

`ensure` makes sure the gate exists with a default value, `set` changes it, and the two
ensure_component helpers keep the [Components] / FDF entries present but gated.  Keeping the
scaffolding in the tree means someone rebuilding from the tarball flips one number instead of
re-deriving where the blocks go.

Usage:
    gates.py ensure   <dsc> VERMEER_BANNER [default]
    gates.py set      <dsc> VERMEER_BANNER 1
    gates.py banner   <dsc> <fdf>
    gates.py qemu     <dsc> [enable]        # PCDs + serial libs + MMIO windows block
"""
import pathlib
import re
import sys

BANNER_COMPONENT = """
!if $(VERMEER_BANNER) == 1
  vermeerPkg/Drivers/VermeerBannerDxe/VermeerBannerDxe.inf
!endif
"""

BANNER_FDF = """
!if $(VERMEER_BANNER) == 1
  INF vermeerPkg/Drivers/VermeerBannerDxe/VermeerBannerDxe.inf
!endif
"""

QEMU_BLOCK = """
# --- QEMU bring-up overrides (never shipped; QEMU_BRINGUP defaults to 0) ------------------
!if $(QEMU_BRINGUP) == 1
[PcdsFixedAtBuild.common]
  gArmTokenSpaceGuid.PcdGicDistributorBase|0x08000000
  gArmTokenSpaceGuid.PcdGicRedistributorsBase|0x080A0000
  gArmTokenSpaceGuid.PcdArmArchTimerSecIntrNum|29
  gArmTokenSpaceGuid.PcdArmArchTimerIntrNum|30
  gEfiMdeModulePkgTokenSpaceGuid.PcdSerialRegisterBase|0x09000000
  gArmPlatformTokenSpaceGuid.PL011UartClkInHz|24000000
  gEfiMdePkgTokenSpaceGuid.PcdUartDefaultBaudRate|115200
  gEfiMdeModulePkgTokenSpaceGuid.PcdSerialBaudRate|115200
  gEfiMdeModulePkgTokenSpaceGuid.PcdSerialUseHardwareFlowControl|FALSE
  gEfiMdePkgTokenSpaceGuid.PcdUartDefaultReceiveFifoDepth|0

[LibraryClasses]
  SerialPortLib|ArmPlatformPkg/Library/PL011SerialPortLib/PL011SerialPortLib.inf
  PL011UartLib|ArmPlatformPkg/Library/PL011UartLib/PL011UartLib.inf
  PL011UartClockLib|ArmPlatformPkg/Library/PL011UartClockLib/PL011UartClockLib.inf

[BuildOptions]
  *_*_AARCH64_CC_FLAGS = -DQEMU_BRINGUP=1
!endif

# --- end of QEMU bring-up overrides -------------------------------------------------------
"""


def ensure(dsc, name, default="0"):
    s = open(dsc).read()
    if re.search(r"^\s*%s\s*=" % re.escape(name), s, re.M):
        return False
    line = "  %-30s = %s\n" % (name, default)
    m = re.search(r"^  VERMEER_PAINT[^\n]*\n", s, re.M)
    if m:
        s = s.replace(m.group(0), m.group(0) + line, 1)
    else:
        s = s.replace("[Defines]\n", "[Defines]\n" + line, 1)
    open(dsc, "w").write(s)
    return True


def set_gate(dsc, name, value):
    s = open(dsc).read()
    s2, n = re.subn(r"(^\s*%s\s*=\s*)\S+" % re.escape(name), r"\g<1>%s" % value, s,
                    count=1, flags=re.M)
    assert n == 1, "gate %s not found in %s" % (name, dsc)
    open(dsc, "w").write(s2)


def banner(dsc, fdf):
    ensure(dsc, "VERMEER_BANNER", "0")
    s = open(dsc).read()
    if "VermeerBannerDxe" not in s:
        assert "[Components]" in s
        s = s.replace("[Components]", "[Components]" + BANNER_COMPONENT, 1)
        open(dsc, "w").write(s)
    f = open(fdf).read()
    if "VermeerBannerDxe" not in f:
        anchor = "!include Include/RAW.inc"
        assert anchor in f, "no RAW.inc include in the FDF"
        f = f.replace(anchor, anchor + "\n" + BANNER_FDF, 1)
        open(fdf, "w").write(f)




VERMEER_GOP_COMPONENT = """
!if $(VERMEER_GOP) == 1
  SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf
!endif
"""

VERMEER_GOP_FDF = """
!if $(VERMEER_GOP) == 1
  INF SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf
!endif
"""

KEYPROBE_COMPONENT = """
!if $(VERMEER_KEYPROBE) == 1
  vermeerPkg/Drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.inf
!endif
"""

KEYPROBE_FDF = """
!if $(VERMEER_KEYPROBE) == 1
  INF vermeerPkg/Drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.inf
!endif
"""

# The stock firmware reads volume-up from PM8550 GPIO 6, not from a TLMM pad, so the only way
# to get a key without writing an SPMI/PMIC driver ourselves is to let the vendor trio in:
# SPMIDxe publishes the SPMI protocol, PmicDxe consumes it, ButtonsDxe turns PMIC GPIO edges
# into SimpleTextIn key strokes.  Everything else (Clock, Display, UFS, USB) stays out, so
# the panel is not touched.  Any module whose DEPEX cannot be satisfied is skipped silently by
# the DXE core -- that is what makes this experiment safe to try.
VENDOR_INPUT_COMPONENT = """
!if $(VERMEER_VENDOR_INPUT) == 1
  Binaries/vermeer/QcomPkg/Drivers/TzDxe/ScmDxeCompat.inf
  Binaries/vermeer/QcomPkg/Drivers/SPMIDxe/SPMIDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/PmicGlinkDxe/PmicGlinkDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/SmemDxe/SmemDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.inf
  Binaries/vermeer/QcomPkg/Drivers/TLMMDxe/TLMMDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/RpmhDxe/RpmhDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/VcsDxe/VcsDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/DALSYSDxe/DALSYSDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/ButtonsDxe/ButtonsDxe.inf
!endif
"""

VENDOR_INPUT_FDF = """
!if $(VERMEER_VENDOR_INPUT) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/TzDxe/ScmDxeCompat.inf
  INF Binaries/vermeer/QcomPkg/Drivers/SPMIDxe/SPMIDxe.inf
  INF Binaries/vermeer/QcomPkg/Drivers/PmicGlinkDxe/PmicGlinkDxe.inf
  INF Binaries/vermeer/QcomPkg/Drivers/SmemDxe/SmemDxe.inf
  INF Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.inf
  INF Binaries/vermeer/QcomPkg/Drivers/TLMMDxe/TLMMDxe.inf
  INF Binaries/vermeer/QcomPkg/Drivers/RpmhDxe/RpmhDxe.inf
  INF Binaries/vermeer/QcomPkg/Drivers/VcsDxe/VcsDxe.inf
  INF Binaries/vermeer/QcomPkg/Drivers/DALSYSDxe/DALSYSDxe.inf
  INF Binaries/vermeer/QcomPkg/Drivers/ButtonsDxe/ButtonsDxe.inf
!endif
"""


def _replace_gated_block(text, name, block):
    """Replace an existing ``!if $(NAME) == 1 ... !endif`` block with the canonical text.

    The old version of this helper only inserted the block when the marker string was absent,
    so editing the block content (e.g. adding TLMMDxe to the vendor input set) silently had no
    effect and the module never appeared in the FD.  Always rewriting the block keeps the
    scaffolding and the source of truth in sync.
    """
    import re as _re
    pat = _re.compile(
        r"!if \$\(%s\) == 1\r?\n.*?!endif\r?\n" % _re.escape(name),
        _re.S,
    )
    if pat.search(text):
        return pat.sub(block.lstrip("\n"), text, count=1)
    return None


def _add_gated(dsc, fdf, name, component, fdf_block, marker):
    ensure(dsc, name, "0")
    s = open(dsc).read()
    new_s = _replace_gated_block(s, name, component)
    if new_s is None:
        assert "[Components]" in s
        new_s = s.replace("[Components]", "[Components]" + component, 1)
    if new_s != s:
        open(dsc, "w").write(new_s)
    f = open(fdf).read()
    new_f = _replace_gated_block(f, name, fdf_block)
    if new_f is None:
        anchor = "!include Include/RAW.inc"
        assert anchor in f, "no RAW.inc include in the FDF"
        new_f = f.replace(anchor, anchor + "\n" + fdf_block, 1)
    if new_f != f:
        open(fdf, "w").write(new_f)


def keyprobe(dsc, fdf):
    _add_gated(dsc, fdf, "VERMEER_KEYPROBE", KEYPROBE_COMPONENT, KEYPROBE_FDF,
               "VermeerKeyProbeDxe")
    # keys111: bring GOP in through the same idempotent plumbing (survives pristine restore)
    gop(dsc, fdf)



def gop(dsc, fdf):
    return  # keys112: SimpleFbDxe already shipped via Include/DXE.inc
    """Add SimpleFbDxe (EFI_GRAPHICS_OUTPUT_PROTOCOL) under VERMEER_GOP.

    The FDF block is enough to place the driver in the FV.  Include/APRIORI.inc is pulled
    into the same FV, so a duplicate line there makes GenFv abort with
    "the 54th file and 63th file have the same file GUID".  Strip it from APRIORI.inc.
    """
    ensure(dsc, "VERMEER_GOP", "0")
    _add_gated(dsc, fdf, "VERMEER_GOP", VERMEER_GOP_COMPONENT, VERMEER_GOP_FDF, "Vermeer GOP")
    set_gate(dsc, "VERMEER_GOP", "1")
    apriori = pathlib.Path(fdf).parent / 'Include' / 'APRIORI.inc'
    if apriori.exists():
        txt = apriori.read_text(encoding='utf-8', errors='surrogateescape')
        kept = [ln for ln in txt.splitlines(True) if 'SimpleFbDxe.inf' not in ln]
        if len(kept) != len(txt.splitlines(True)):
            apriori.write_text(''.join(kept), encoding='utf-8', errors='surrogateescape')
            print('   apriori: stripped duplicate SimpleFbDxe line(s)')


def vendor_input(dsc, fdf):
    _add_gated(dsc, fdf, "VERMEER_VENDOR_INPUT", VENDOR_INPUT_COMPONENT, VENDOR_INPUT_FDF,
               "VERMEER_VENDOR_INPUT")

def qemu(dsc, enable=False):
    ensure(dsc, "QEMU_BRINGUP", "0")
    s = open(dsc).read()
    if "PL011SerialPortLib" not in s:
        assert "[Components]" in s
        s = s.replace("[Components]", QEMU_BLOCK + "\n[Components]", 1)
        open(dsc, "w").write(s)
    if enable:
        set_gate(dsc, "QEMU_BRINGUP", "1")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "ensure":
        ensure(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "0")
    elif cmd == "set":
        set_gate(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "banner":
        banner(sys.argv[2], sys.argv[3])
    elif cmd == "keyprobe":
        keyprobe(sys.argv[2], sys.argv[3])
    elif cmd == "vendorinput":
        vendor_input(sys.argv[2], sys.argv[3])
    elif cmd == "gop":
        gop(sys.argv[2], sys.argv[3])
    elif cmd == "qemu":
        qemu(sys.argv[2], enable=("enable" in sys.argv[3:]))
    else:
        sys.exit(__doc__)
