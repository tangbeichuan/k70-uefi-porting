set +e
X=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref
ls -l $X
echo "--- menu ---"; grep -i 'VermeerMenuDxe' $X || echo MISSING
echo "--- textin/out console drivers ---"; grep -iE 'ConSplitterDxe|SimpleTextInOutSerial|GraphicsConsoleDxe' $X | head