#!/usr/bin/env bash
# Print the [Depex] of every vendor driver that keys12/keys13 may load, so we can tell which
# of them would be skipped if a publisher is missing (built-in depex file = binary blob).
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
for inf in \
  SmemDxe/SmemDxe.inf DALSYSDxe/DALSYSDxe.inf HWIODxeDriver/HWIODxeDriver.inf \
  ChipInfoDxe/ChipInfoDxe.inf PlatformInfoDxe/PlatformInfoDxe.inf \
  ProjectInfoDxe/ProjectInfoDxe.inf HALIOMMU/HALIOMMU.inf IPCCDxe/IPCCDxe.inf \
  CmdDbDxe/CmdDbDxe.inf PwrUtilsDxe/PwrUtilsDxe.inf NpaDxe/NpaDxe.inf \
  RpmhDxe/RpmhDxe.inf VcsDxe/VcsDxe.inf ULogDxe/ULogDxe.inf \
  TLMMDxe/TLMMDxe.inf SPMIDxe/SPMIDxe.inf PmicGlinkDxe/PmicGlinkDxe.inf \
  PmicDxe/PmicDxeLa.inf ButtonsDxe/ButtonsDxe.inf TzDxe/ScmDxeCompat.inf \
  EnvDxe/EnvDxe.inf DALSys.efi ; do
  f="$B/$inf"
  echo "=========== $inf"
  if [ ! -f "$f" ]; then echo "  (missing)"; continue; fi
  awk 'BEGIN{IGNORECASE=1} /^\[Depex\]/{flag=1;next} /^\[/{flag=0} flag && NF {print "  " $0}' "$f"
  # fall back to a depex file reference
  grep -iE '^\s*(depex|.*\.depex)\s*$' "$f" | sed 's/^/  ref: /'
done
