p = r'D:\本地项目-01\_twrp\recovery_a.img'
d = open(p,'rb').read()
for s in (b'Linux version', b'ufshcd', b'recovery.fstab', b'fstab.qcom', b'twrp', b'TWRP', b'init.recovery', b'qcom,ufshc', b'init_speed_params', b'bootconfig'):
    idx = d.find(s)
    print('%-18s %s' % (s.decode(errors="replace"), idx))
# 打印 'Linux version' 附近
i = d.find(b'Linux version')
if i>0:
    print(repr(d[i:i+160]))