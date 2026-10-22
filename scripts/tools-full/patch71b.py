import io
p='/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
old='''  Status2 = gBS->AllocatePages (AllocateAnyPages, EfiBootServicesData, 12, (EFI_PHYSICAL_ADDRESS *)(UINTN)&mUfsDma);
  if (EFI_ERROR (Status2) || (mUfsDma == NULL)) {
    UfsPrint ("[UFS71] alloc failed\\n");
    return;
  }'''
new='''  {
    EFI_PHYSICAL_ADDRESS  MaxAddr;

    MaxAddr = 0xBE000000ULL;   // 必须在 0xc0000000 以下（vu_dma_allowed 的硬约束）
    Status2 = gBS->AllocatePages (AllocateMaxAddress, EfiBootServicesData, 12, &MaxAddr);
    if (EFI_ERROR (Status2)) {
      Status2 = gBS->AllocatePages (AllocateAnyPages, EfiBootServicesData, 12, &MaxAddr);
    }
    if (EFI_ERROR (Status2)) {
      UfsPrint ("[UFS71] alloc failed\\n");
      return;
    }
    mUfsDma = (VOID *)(UINTN)MaxAddr;
  }'''
assert old in s, 'alloc block not found'
s=s.replace(old,new,1)
io.open(p,'w',encoding='utf-8').write(s)
print('alloc patched to <3GiB')