#!/usr/bin/env bash
# github.com:443 is intermittently unreachable from this VM; retry the two
# submodules that are still missing before falling back to any stub.
set +e
cd /root/k70/uefi/Mu_Basecore || exit 1
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 1000
git config --global http.lowSpeedTime 60

try() {
  local path="$1"
  for i in 1 2 3 4 5; do
    echo "--- attempt $i: $path"
    git submodule update --init --depth 1 "$path" 2>&1 | tail -3
    if [ -e "$path/." ] && [ -n "$(ls -A "$path" 2>/dev/null)" ]; then
      echo "    OK"; return 0
    fi
    sleep 5
  done
  echo "    FAILED after 5 attempts"
  return 1
}

try SecurityPkg/DeviceSecurity/SpdmLib/libspdm
echo
echo "===== Silicon/Silicium nested submodule ====="
cd /root/k70/uefi/Silicon/Silicium || exit 1
git submodule status | head -5
git submodule update --init --recursive --depth 1 2>&1 | tail -5

echo
echo "===== state ====="
ls -d /root/k70/uefi/Mu_Basecore/SecurityPkg/DeviceSecurity/SpdmLib/libspdm/include 2>/dev/null && echo "libspdm include present" || echo "libspdm include MISSING"
