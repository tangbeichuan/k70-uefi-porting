set +e
X=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref
ls -l "$X" 2>/dev/null | cat
for n in UsbMsd UsbConfig UsbDevice UsbfnDwc3 VermeerLogDisk VermeerMenu VermeerPmicVerStub; do
  c=$(grep -ci "$n" "$X" 2>/dev/null)
  echo "$n: $c"
done