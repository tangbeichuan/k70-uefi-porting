set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "UIC DONE\|UfsUicCmd (0x04\|LINK_STARTUP\|UECPA\|takeover next\|own descriptors accepted" "$F" | head -20