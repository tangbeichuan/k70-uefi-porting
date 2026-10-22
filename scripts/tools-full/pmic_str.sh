set +e
F=$(find /root/k70/uefi/Binaries -name 'PmicDxe*.efi' | head -1)
echo "F=$F"
strings -n 4 "$F" | grep -nE 'pre-psi|pon|pshold|psi|ignore_pwr|resin' | head -40