set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()
anchor="""    if (FALSE) {
      SetIfcSlot (DTBEXTN_IFC_SIZE, (VOID *)EfiApi_Unsupported);
    }"""
add="""    if (FALSE) {
      SetIfcSlot (DTBEXTN_IFC_SIZE, (VOID *)EfiApi_Unsupported);
    }
    // keys60: 被 vendor 真实调用的槽位，用带参数日志的桩覆盖
    SetIfcSlot (0x40, (VOID *)EfiApi_Slot40);
    SetIfcSlot (0x88, (VOID *)EfiApi_Slot88);
    SetIfcSlot (0x90, (VOID *)EfiApi_Slot90);
    SetIfcSlot (0xa0, (VOID *)EfiApi_SlotA0);"""
assert anchor in s, 'fill anchor missing'
if 'EfiApi_Slot40);' not in s:
    s=s.replace(anchor, add, 1)
    print('overrides inserted')
io.open(p,'w',encoding='utf-8').write(s)
PY
echo "=== build keys60 ==="
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys60 2>&1 | tail -12