#!/usr/bin/env bash
# Why does `apt-get update` 503 on resolute-updates / resolute-backports?
set +e
echo "===== /etc/apt/sources.list ====="
grep -vE '^\s*(#|$)' /etc/apt/sources.list 2>/dev/null || echo "(empty or missing)"
echo
echo "===== sources.list.d ====="
ls -1 /etc/apt/sources.list.d/ 2>/dev/null
for f in /etc/apt/sources.list.d/*; do
  [ -f "$f" ] || continue
  echo "--- $f"
  grep -vE '^\s*(#|$)' "$f"
done
echo
echo "===== deb822 (.sources) ====="
for f in /etc/apt/sources.list.d/*.sources; do
  [ -f "$f" ] || continue
  echo "--- $f"; cat "$f"
done
echo
echo "===== apt proxy settings ====="
grep -rniE 'proxy|Acquire::(http|https)' /etc/apt/apt.conf.d/ /etc/apt/apt.conf 2>/dev/null | head -20 || echo "(none)"
echo
echo "===== env proxy ====="
env | grep -iE 'proxy' || echo "(none)"
echo
echo "===== dns ====="
cat /etc/resolv.conf | grep -vE '^#' | head -6
getent hosts archive.ubuntu.com security.ubuntu.com ports.ubuntu.com
echo
echo "===== what 192.168.1.14:8502 is ====="
(exec 3<>/dev/tcp/192.168.1.14/8502) 2>/dev/null && echo "tcp 8502 open" || echo "tcp 8502 closed"
command -v ip >/dev/null && ip route | head -5
echo
echo "===== retry apt update, full output (head+tail) ====="
timeout 120 apt-get -o Acquire::Retries=1 update 2>&1 | head -25
