set +e
X=/tmp/guid-keys101.xref
echo "=== VermeerMenuDxe in FV? ==="; grep -i 'VermeerMenuDxe' $X || echo "  MISSING"
echo "=== ButtonsDxe / PmicDxe / SPMIDxe ==="; grep -iE ' (ButtonsDxe|PmicDxe|SPMIDxe)$' $X
echo "=== UFSDxe / HALIOMMU (should be absent-ish) ==="; grep -iE ' (UFSDxe|HALIOMMUDxe)$' $X || echo "  none"