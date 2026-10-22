set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
ls -lt run_keys*.sh | head -20
echo "=== grep hard-drop in run_keys7*/8* ==="
grep -ln "hard-dropped\|hard drop\|HALIOMMU" run_keys*.sh | head -20