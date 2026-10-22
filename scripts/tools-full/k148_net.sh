#!/bin/bash
echo '===== local kernel sources? ====='
find / -maxdepth 6 -name 'phy-qcom-qusb2.c' -o -maxdepth 6 -name 'phy-snps-eusb2.c' -o -maxdepth 6 -name 'phy-qcom-eusb2-repeater.c' 2>/dev/null | head
find / -maxdepth 7 -path '*drivers/usb/dwc3/core.h' 2>/dev/null | head
echo '===== curl test ====='
curl -s -m 20 -o /dev/null -w 'raw.githubusercontent: %{http_code}\n' https://raw.githubusercontent.com/torvalds/linux/master/drivers/usb/dwc3/core.h
curl -s -m 20 -o /dev/null -w 'kernel.org: %{http_code}\n' https://git.kernel.org/