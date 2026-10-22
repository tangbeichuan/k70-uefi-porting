set +e
R=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt
for g in Xhci UsbBus UsbMassStorage UsbKb UsbConfig UsbDevice UsbFn; do
  printf "%-16s %s\n" "$g" "$(grep -ic "$g" $R 2>/dev/null)"
done
echo "--- FV 里 usb 相关 GUID 名 ---"
grep -iE 'usb' $R | head -20
echo "--- vermeer.dsc 里 usb 组件 ---"
grep -niE 'usb' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc | head -20
echo "--- fdf 里 usb ---"
grep -niE 'usb' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf | head -20
echo "--- Binaries 里的 USB 驱动 ---"
ls /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers | grep -i usb