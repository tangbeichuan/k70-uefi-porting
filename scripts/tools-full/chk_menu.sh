set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
ls -l "$F" 2>/dev/null || find /mnt/d/本地项目-01/_k70port_extract/port-drivers -name "VermeerMenuDxe.c"
grep -n "GOP\|gEfiGraphicsOutputProtocolGuid\|ConOut = \|\[UI\] ConIn" "$F" | head -12