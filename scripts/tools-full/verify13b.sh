#!/usr/bin/env bash
# Rebuild A and B just far enough to capture each build's FV/Guid.xref, which is the
# authoritative list of what actually landed in the FD.  The FD itself is FV-compressed, so
# grepping it for driver names proves nothing (that is why this exists).
set -e -o pipefail
TOOLS=/mnt/d/本地项目-01/_k70port_extract
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref

for mode in B A; do
  echo "################## rebuild $mode ##################"
  bash "$TOOLS/wsl/build_keys13.sh" "$mode" | tail -3
  cp "$FV" "/tmp/guid-13$mode.xref"
  echo "--- what the $mode FD contains (vendor drivers only) ---"
  grep -iE ' (NpaDxe|ULogDxe|ButtonsDxe|SPMIDxe|PmicDxe|PmicGlinkDxe|TLMMDxe|RpmhDxe|VcsDxe|ICBDxe|UFSDxe|RscDxe|EnvDxe|SmemDxe|DALSYSDxe)$' "/tmp/guid-13$mode.xref" || echo "  (none)"
  echo "  vendor driver count in FV: $(grep -ciE 'QcomPkg|Binaries' /dev/null || true)"
done

echo
echo "################## diff A vs B ##################"
diff <(awk '{print $1, $2}' /tmp/guid-13B.xref | sort) <(awk '{print $1, $2}' /tmp/guid-13A.xref | sort) || true
