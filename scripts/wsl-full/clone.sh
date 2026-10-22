#!/usr/bin/env bash
# Fetch the Mu-Silicium tree that sheng actually builds from (UniXNU/uefi-sheng, branch sheng).
# WSL can reach github.com:443 directly (verified), so a plain git clone works here.
set -o pipefail
mkdir -p /root/k70
cd /root/k70 || exit 1

if [ ! -d uefi/.git ]; then
  echo "===== cloning uefi-sheng (branch sheng) ====="
  git clone --depth 1 -b sheng https://github.com/UniXNU/uefi-sheng.git uefi 2>&1 | tail -5
else
  echo "===== already cloned, fetching ====="
  git -C uefi fetch --depth 1 origin sheng 2>&1 | tail -3
fi
echo "clone exit: $?"
echo
echo "===== HEAD ====="
git -C uefi log --oneline -1
git -C uefi status --porcelain | head -5
echo
echo "===== .gitmodules ====="
cat uefi/.gitmodules 2>/dev/null | grep -E '^\s*(path|url)' | paste - - | sed 's/\t/  ->  /'
echo
echo "===== top level ====="
ls uefi
echo
echo "===== size ====="
du -sh uefi 2>/dev/null
