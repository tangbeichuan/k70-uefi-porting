set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
grep -n "mBlob;" "$F" | head -3
grep -n "mBlobSize;" "$F" | head -3