set +e
cd /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
echo "=== 关键模块还在不在 ==="
grep -E 'VermeerDtbExtnDxe|VermeerKeyProbeDxe|UFSDxe|EnvDxe' Guid.xref
echo "=== HALIOMMU/PmicDxe ==="
grep -iE 'halionmu|PmicDxe' Guid.xref
echo "=== FVMAIN 条目数 ==="
grep -c '^0x' FVMAIN.Fv.txt