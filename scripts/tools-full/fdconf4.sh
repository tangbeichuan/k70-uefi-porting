set +e
C=/root/k70/uefi/Resources/Configs/vermeer.toml
ls -l "$C"
grep -n 'uefi_fd' -A6 "$C"