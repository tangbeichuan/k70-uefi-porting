set +e
U=/root/k70/uefi
echo "=== serial-related drivers/libs in tree ==="
find "$U/Silicon" "$U/Platforms/Xiaomi/vermeerPkg" -iname '*Serial*' -o -iname '*Uart*' 2>/dev/null | grep -viE '\.obj$|\.c\~' | head -40
echo
echo "=== vermeer.dsc / fdf references to Serial ==="
grep -nE 'Serial|UART|Uart' "$U/Platforms/Xiaomi/vermeerPkg/vermeer.dsc" "$U/Platforms/Xiaomi/vermeerPkg/vermeer.fdf" 2>/dev/null | head -30
echo
echo "=== vermeer.dtb: serial/uart nodes ==="
dtc -I dtb -O dts "$U/Platforms/Xiaomi/vermeerPkg/FdtBlob/sm8550-xiaomi-vermeer.dtb" 2>/dev/null | grep -nE 'serial@|uart|geniqup|stdout-path|qcom,geni' | head -40
