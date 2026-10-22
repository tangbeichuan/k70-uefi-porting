set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys129/keys130/g' run_keys129.sh > run_keys130.sh
sed -e 's/keys129/keys130/g' build_keys129.sh > build_keys130.sh
sed -i 's|patch_usb128.py|patch_usb130.py|' build_keys130.sh
grep -n 'patch_usb\|patch_pmicstub' build_keys130.sh
chmod +x run_keys130.sh build_keys130.sh
bash run_keys130.sh 2>&1 | tail -6
echo "=== APRIORI usb after build ==="
grep -n -i 'usbconfig\|usbinit\|usbmsd\|usbdevice\|usbfn\|VermeerLogDisk' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc | head