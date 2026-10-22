#!/usr/bin/env bash
# Locate the binary that owns "UFS.coreDxeLib.c +163" and dump the strings UFSDxe actually uses.
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
EFI=$B/UFSDxe/UFSDxe.efi

echo "=== which vendor .efi mentions UFS.coreDxeLib ?"
grep -ril 'UFS\.coreDxeLib' "$B" 2>/dev/null | head -20
echo
echo "=== same, looser (coreDxeLib / UFS.) ==="
grep -ril 'coreDxeLib' "$B" 2>/dev/null | head -20
echo
echo "=== UFSDxe.efi: everything with 'ufs' / 'vcc' / 'gear' / 'bootlun' (ascii) ==="
strings -a "$EFI" | grep -iE 'ufs|vcc|gear|bootlun|lun|refclk|descriptor' | sort -u | head -60
echo
echo "=== UFSDxe.efi: UTF-16 strings (any, first 40) ==="
strings -el "$EFI" | head -40
echo
echo "=== UFSDxe.efi: strings that look like variable / protocol names ==="
strings -a "$EFI" | grep -E '^[A-Za-z_][A-Za-z0-9_.-]{4,40}$' | sort -u | head -60
