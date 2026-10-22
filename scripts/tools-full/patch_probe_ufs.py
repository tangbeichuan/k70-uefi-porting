import io,sys
C='/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c'
I='/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.inf'
B='/mnt/d/本地项目-01/_tools/ufs_direct_block.c'
s=io.open(C,encoding='utf-8',errors='replace').read()
if 'UFS71' in s:
    print('already patched'); sys.exit(0)
blk=io.open(B,encoding='utf-8',errors='replace').read()
anchor='/**\n  Entry point.\n**/'
if anchor not in s:
    anchor='Entry point.'
    print('fallback anchor')
s=s.replace(anchor, blk+anchor,1)
if 'CacheMaintenanceLib.h' not in s:
    s=s.replace('#include <Library/MemoryAllocationLib.h>',
                '#include <Library/MemoryAllocationLib.h>\n#include <Library/CacheMaintenanceLib.h>',1)
s=s.replace('  Say (mHeader);\n','  Say (mHeader);\n\n  UfsDirectTest ();\n',1)
io.open(C,'w',encoding='utf-8').write(s)
print('driver patched, bytes=',len(s))
t=io.open(I,encoding='utf-8',errors='replace').read()
if 'CacheMaintenanceLib' not in t:
    t=t.replace('  BaseLib\n','  BaseLib\n  CacheMaintenanceLib\n',1)
    io.open(I,'w',encoding='utf-8').write(t)
    print('inf patched')