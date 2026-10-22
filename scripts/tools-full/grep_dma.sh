set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "AllocatePool\|AllocatePages\|mSkipUfsTest\|takeover\|0x50\|UfsDma" "$F" | head -30