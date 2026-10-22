set +e
D=/mnt/d/本地项目-01/_twrp/Image
ls -l $D/vendor_boot.dtb
dtc -I dtb -O dts $D/vendor_boot.dtb 2>/dev/null > /tmp/vb.dts || echo "dtc failed"
wc -l /tmp/vb.dts
grep -nE "ufshc|init-speed|init_speed|spm-level|hs-gear|qcom,ufs" /tmp/vb.dts | head -20