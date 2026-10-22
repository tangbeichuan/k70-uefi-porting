import io
p='/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if 'UFS79' in s: print('already'); raise SystemExit
old='''    UfsPrint ("[UFS75] UIC DONE - no doorbell sent, power-cycle safe\\n");
    return;
  }'''
new='''    UfsPrint ("[UFS75] UIC DONE\\n");
  }

  //
  // UFS79: 主机控制器复位 + 干净重初始化（清掉上一任驱动留下的半死状态）
  //
  UfsPrint ("[UFS79] HCE=0 (host reset)...\\n");
  UfsWr (0x34, 0);
  if (!UfsWait (0x34, 1, 0, 1000)) { UfsPrint ("[UFS79] HCE did not clear - stop\\n"); return; }
  UfsPrint ("[UFS79] HCE=1...\\n");
  UfsWr (0x34, 1);
  if (!UfsWait (0x34, 1, 1, 1000)) { UfsPrint ("[UFS79] HCE did not set - stop\\n"); return; }
  if (!UfsWait (0x30, 1, 1, 2000)) { UfsPrint ("[UFS79] UCRDY not ready - stop\\n"); return; }
  AsciiSPrint (Line, sizeof (Line), "[UFS79] HCS=%08x, link startup...\\n", UfsRd (0x30));
  UfsPrint (Line);
  {
    UINT32  R2;
    UINT32  O3;
    UfsUicCmd (0x04, 0, 0, 0, &R2, &O3);
    AsciiSPrint (Line, sizeof (Line), "[UFS79] LINK_STARTUP res=%08x arg3=%08x\\n", R2, O3);
    UfsPrint (Line);
  }
  UfsPrint ("[UFS79] reinit done, takeover next\\n");'''
assert old in s
s=s.replace(old,new,1)
io.open(p,'w',encoding='utf-8').write(s)
print('keys79 reset block inserted')