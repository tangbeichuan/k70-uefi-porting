set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
grep -nE 'mBlob|mBlobSize|NodeToOffset|FdtGetProp \(' "$F" | head -30
echo "--- FdtGetProp body ---"
sed -n "/^FdtGetProp/,/^}/p" "$F" | head -40