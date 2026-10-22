set +e
F=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt
ls -l "$F"
grep -i 'UsbfnDwc3\|UsbDevice\|UsbMsd\|UsbPwrCtrl\|LogDisk' "$F" | head -10