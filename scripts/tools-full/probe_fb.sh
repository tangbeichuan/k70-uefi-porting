set +e
D=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== vermeer.dsc: FrameBuffer PCDs / SimpleFb / GraphicsConsole ==="
grep -n "PcdFrameBuffer\|SimpleFb\|GraphicsConsole\|PcdVideoHorizontalResolution\|PcdVideoVerticalResolution" $D/vermeer.dsc
echo "=== APRIORI: GraphicsConsole / RscDxe lines ==="
grep -n "GraphicsConsole\|RscDxe\|ConSplitter\|SimpleTextInOutSerial" $D/Include/APRIORI.inc
echo "=== fdf: [FV] section markers ==="
grep -n "^\[FV\|^!include\|RscDxe\|GraphicsConsole" $D/vermeer.fdf | head -20