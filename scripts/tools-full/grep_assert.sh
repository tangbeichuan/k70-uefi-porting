set +e
grep -rn 'image_size' /mnt/d/本地项目-01/_k70port_extract/wsl/*.sh /mnt/d/本地项目-01/_k70port_extract/wsl/*.py 2>/dev/null | head
grep -rln 'img_size == len(shim)' /mnt/d/本地项目-01/_k70port_extract 2>/dev/null | head