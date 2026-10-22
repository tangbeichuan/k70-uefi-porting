set +e
U=/root/k70/uefi
echo "=== Mu_Basecore USB drivers ==="
ls "$U/Mu_Basecore/MdeModulePkg/Bus/Usb" 2>/dev/null
echo
echo "=== any *Serial*Usb* / CdcAcm / Ch34 / Cp210 in tree ==="
find "$U" -iname '*Cdc*' -o -iname '*Ch34*' -o -iname '*Cp210*' -o -iname '*UsbSerial*' 2>/dev/null | head -20
echo
echo "=== PL011 / GeniSerial in Mu_Basecore? ==="
find "$U/Mu_Basecore" "$U/ARM" -iname '*PL011*' -o -iname '*GeniSerial*' 2>/dev/null | head -20
