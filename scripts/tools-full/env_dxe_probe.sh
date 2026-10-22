#!/bin/bash
U=/root/k70/uefi
E=$U/Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.efi
echo "=== EnvDxe strings (selected) ==="
strings -n 5 $E | grep -iE 'dtb|dt |hob|xbl|protocol|extension|env' | head -30
echo
echo "=== does EnvDxe contain gEfiDtbExtensionHobGuid bytes? ==="
python3 - <<'PY'
d=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.efi','rb').read()
g=bytes.fromhex('e8e1063af661eb11bbed4b476e2ff6a7')
i=d.find(g)
print('hob guid offset:', hex(i) if i>=0 else 'not found')
# also 3A06E1E8 61F6 11EB BBED 4B476E2FF6A7 in "network order" variant
g2=bytes.fromhex('3a06e1e861f611ebbbed4b476e2ff6a7')
print('variant2:', hex(d.find(g2)))
PY
echo
echo "=== who links PlatformPeiLib ==="
grep -rn "PlatformPeiLib" $U/Platforms/Xiaomi/vermeerPkg $U/Silicon/Qualcomm/QcomPkg/*.dsc $U/Silicon/Silicium/SiliciumPkg/*.dsc 2>/dev/null | head -10
echo
echo "=== vermeer dsc PEI section ==="
grep -n -A25 '\[Components.ARM\|\[Components\]\|Pei' $U/Platforms/Xiaomi/vermeerPkg/vermeer.dsc | head -60
