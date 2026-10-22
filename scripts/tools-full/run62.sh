set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()
old = '''  if ((mBlob != NULL) && (A1 >= (UINTN)mBlob) && (A1 < (UINTN)mBlob + mBlobSize)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN]   arg1 -> \\"%a\\"\\n", (CONST CHAR8 *)A1));
  }'''
new = '''  if ((A1 >= 0x80000000ULL) && (A1 < 0x100000000ULL)) {
    CONST UINT8  *B = (CONST UINT8 *)A1;
    DEBUG ((
      DEBUG_ERROR,
      "[DTBEXTN]   a1[0..15] = %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x  '%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c'\\n",
      B[0], B[1], B[2], B[3], B[4], B[5], B[6], B[7],
      B[8], B[9], B[10], B[11], B[12], B[13], B[14], B[15],
      (B[0] >= 0x20 && B[0] < 0x7F) ? B[0] : '.',
      (B[1] >= 0x20 && B[1] < 0x7F) ? B[1] : '.',
      (B[2] >= 0x20 && B[2] < 0x7F) ? B[2] : '.',
      (B[3] >= 0x20 && B[3] < 0x7F) ? B[3] : '.',
      (B[4] >= 0x20 && B[4] < 0x7F) ? B[4] : '.',
      (B[5] >= 0x20 && B[5] < 0x7F) ? B[5] : '.',
      (B[6] >= 0x20 && B[6] < 0x7F) ? B[6] : '.',
      (B[7] >= 0x20 && B[7] < 0x7F) ? B[7] : '.',
      (B[8] >= 0x20 && B[8] < 0x7F) ? B[8] : '.',
      (B[9] >= 0x20 && B[9] < 0x7F) ? B[9] : '.',
      (B[10] >= 0x20 && B[10] < 0x7F) ? B[10] : '.',
      (B[11] >= 0x20 && B[11] < 0x7F) ? B[11] : '.',
      (B[12] >= 0x20 && B[12] < 0x7F) ? B[12] : '.',
      (B[13] >= 0x20 && B[13] < 0x7F) ? B[13] : '.',
      (B[14] >= 0x20 && B[14] < 0x7F) ? B[14] : '.',
      (B[15] >= 0x20 && B[15] < 0x7F) ? B[15] : '.'
      ));
  }'''
assert old in s, 'arg1 block not found'
s = s.replace(old, new, 1)
io.open(p,'w',encoding='utf-8').write(s)
print('arg1 hexdump added')
PY
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys62 2>&1 | tail -5
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys62.fd" keys62 2>&1 | tail -3