set +e
sed -n '455,480p' /root/k70/uefi/build_uefi.py
echo "=== find config json used for vermeer ==="
grep -rn 'config_data' /root/k70/uefi/build_uefi.py | head -5
ls /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/ | head -30