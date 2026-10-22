#!/usr/bin/env bash
# Probe the WSL Ubuntu side: identity, resources, toolchain, and which GitHub
# endpoints are reachable from inside the VM (the Windows side only gets api/raw/codeload).
set +e
echo "===== identity ====="
id
. /etc/os-release
echo "distro: ${PRETTY_NAME}"
echo "kernel: $(uname -r)  arch: $(uname -m)"
echo "wsl: ${WSL_DISTRO_NAME:-?} interop=${WSL_INTEROP:-none}"
echo
echo "===== resources ====="
echo "cpus: $(nproc)"
free -h | head -2
df -h / /mnt/d 2>/dev/null | sed 's/^/  /'
echo
echo "===== toolchain present? ====="
for c in git curl wget python3 pip3 clang clang-18 clang-17 ld.lld lld-link nasm iasl dtc cmake ninja make gcc g++ unifdef mtools; do
  if command -v "$c" >/dev/null 2>&1; then printf '  %-10s %s\n' "$c" "$(command -v "$c")"; else printf '  %-10s MISSING\n' "$c"; fi
done
echo "  python3 --version: $(python3 --version 2>&1)"
echo
echo "===== dpkg: dev packages ====="
for p in uuid-dev build-essential python3-pip python3-venv nasm acpica-tools device-tree-compiler mtools ninja-build clang lld; do
  if dpkg -s "$p" >/dev/null 2>&1; then printf '  %-22s installed\n' "$p"; else printf '  %-22s absent\n' "$p"; fi
done
echo
echo "===== network from inside WSL ====="
for u in https://github.com https://api.github.com/zen https://codeload.github.com https://raw.githubusercontent.com https://pypi.org/simple/ https://archive.ubuntu.com/ubuntu/ http://archive.ubuntu.com/ubuntu/; do
  code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$u" 2>&1)
  printf '  %-45s %s\n' "$u" "$code"
done
echo
echo "===== git over https (github.com:443) ====="
GIT_TERMINAL_PROMPT=0 timeout 40 git ls-remote --heads https://github.com/UniXNU/UniXNU-sheng 2>&1 | head -3
echo "git exit: $?"
echo
echo "===== apt reachability ====="
timeout 90 apt-get -o Acquire::http::Timeout=20 update 2>&1 | tail -4
