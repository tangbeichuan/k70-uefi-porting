set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys123/keys124/g' run_keys123.sh > run_keys124.sh
sed -e 's/keys123/keys124/g' build_keys123.sh > build_keys124.sh
# menu source must be re-copied from port-drivers (patch_menu101 copies whole dir) -> ensure our patched file is the source
cp /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c.bak124 2>/dev/null
chmod +x run_keys124.sh build_keys124.sh
bash run_keys124.sh 2>&1 | tail -8