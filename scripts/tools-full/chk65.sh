set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
grep -n "mLastNode" "$F" | head
echo "--- mInstalled 声明行 ---"
grep -n "STATIC BOOLEAN            mInstalled" "$F"