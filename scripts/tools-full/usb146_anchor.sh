#!/bin/bash
# usb146_anchor.sh -- find PHY-tuning strings, module, and the indirect calls
# that follow the last "WRITING: reg" site (anchor for the crash)
set -u
TO=/mnt/d/本地项目-01/_tools
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv

python3 - "$FV" <<'PY'
import struct,sys,uuid
fv=open(sys.argv[1],'rb').read()
hv=fv.find(b"_FVH",0,0x1000); base=hv-0x28
hdrlen=struct.unpack_from("<H",fv,base+0x30)[0]
off=base+hdrlen; mods=[]
while off+0x18<=len(fv):
    t=fv[off+0x12]; size=fv[off+0x14]|(fv[off+0x15]<<8)|(fv[off+0x16]<<16)
    if size<0x18 or t==0xFF: break
    guid=str(uuid.UUID(bytes_le=fv[off:off+16]))
    # look for UI section
    name=guid
    p=off+0x18; b=off+size
    payload=None
    while p+4<=b:
        ss=fv[p]|(fv[p+1]<<8)|(fv[p+2]<<16); st=fv[p+3]
        if ss<4: break
        if st==0x15:
            name=fv[p+4:p+ss].decode('utf-16-le','ignore').rstrip('\x00')
        if st==0x19:  # PE32
            p32=p+4
            payload=(p32,fv[p32:p32+ss-4])
        p=(p+ss+3)&~3
    mods.append((off,off+size,guid,name,payload))
    off=(off+size+7)&~7
print("modules",len(mods))
for needle in (b"usb_repeater_init", b"WRITING", b"tuning_allowed", b"transaction"):
    i=0; print("\n### needle",needle)
    while True:
        i=fv.find(needle,i)
        if i<0: break
        owner=[m for m in mods if m[0]<=i<m[1]]
        if owner:
            o=owner[0]
            # was this string start?
            st = i==0 or fv[i-1]==0
            print("  @0x%x %s rva_in_module=0x%x start_of_string=%s"%(i,o[3],i-o[0],st))
        i+=1
PY
