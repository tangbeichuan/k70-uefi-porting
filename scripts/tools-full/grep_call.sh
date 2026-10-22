set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "UfsDirectTest\|ScanBoardWindows\|DumpHobs (\|InteractiveDemo\|Say (mHeader\|UFS74_DUMPONLY" "$F" | head -20