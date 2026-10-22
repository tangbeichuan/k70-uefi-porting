import io
p='VermeerDtbExtnDxe.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if 'EfiApi_Slot20' in s:
    print('already'); raise SystemExit
anchor='STATIC EFI_STATUS\nEfiApi_Slot40 ('
assert anchor in s, 'anchor missing'
new='''STATIC EFI_STATUS
EfiApi_Slot20 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  LogArgs ("slot 0x20", A0, A1, A2, A3);
  return SlotGetGeneric (0x20, "slot 0x20", A0, A1, A2, A3, 64);
}

'''
s=s.replace(anchor,new+anchor,1)
old='    SetIfcSlot (0x98, (VOID *)EfiApi_Slot98);'
assert old in s, 'setifc anchor missing'
s=s.replace(old, old+'\n    SetIfcSlot (0x20, (VOID *)EfiApi_Slot20);',1)
io.open(p,'w',encoding='utf-8').write(s)
print('slot 0x20 added')