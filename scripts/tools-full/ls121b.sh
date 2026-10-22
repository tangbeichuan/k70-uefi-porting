set +e
L=/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys121.sh
wc -l "$L"
head -40 "$L"
echo "====="
B=/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys121.sh
ls -l "$B" 2>/dev/null
grep -n 'DROP\|token\|usb' "$B" 2>/dev/null | head -30