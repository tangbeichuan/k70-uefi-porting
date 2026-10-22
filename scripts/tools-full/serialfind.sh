set +e
U=/root/k70/uefi
echo "=== USB 串口 / CDC 相关驱动 ==="
find "$U" -iname '*usbserial*' -o -iname '*cdc*' -o -iname '*SerialPortLib*' 2>/dev/null | grep -v Build/ | head -30
echo
echo "=== QcomPkg 里 GENI/QUP/UART 驱动 ==="
find "$U/Silicon" -iname '*qup*' -o -iname '*uart*' -o -iname '*geni*' 2>/dev/null | grep -v Build/ | head -30
echo
echo "=== 我们当前用的 SerialPortLib 映射 ==="
grep -rn "SerialPortLib|" "$U/Platforms/Xiaomi/vermeerPkg/vermeer.dsc" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" 2>/dev/null | head