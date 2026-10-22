set +e
F=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt
for n in UsbMsd UsbConfig UsbDevice UsbfnDwc3 VermeerLogDisk VermeerMenu VermeerPmicVerStub; do
  c=$(grep -ci "$n" "$F")
  echo "$n: $c"
done