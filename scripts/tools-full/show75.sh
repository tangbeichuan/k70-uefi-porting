set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "UFS71\|UFS74\|UfsRd\|UfsWr\|SmmuRd\|Uint32Write\|UtRd\|mUfsDma" "$F" | head -60
echo ---
sed -n '/direct UFS probe/,/^}/p' "$F" | head -80