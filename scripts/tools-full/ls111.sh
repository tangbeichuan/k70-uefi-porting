set +e
B=/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys111.sh
ls -l "$B"
grep -n 'DROP\|usb\|Usb' "$B" | head -40