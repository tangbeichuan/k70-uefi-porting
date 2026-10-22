set +e
grep -rIl 'pre-psi' /root/k70/uefi --include='*.dts' --include='*.dtsi' --include='*.dtb' 2>/dev/null | head
echo "--- dtb files containing pre-psi (binary grep)"
for f in $(find /root/k70/uefi -name '*.dtb' 2>/dev/null | head -40); do
  if strings -n 6 "$f" 2>/dev/null | grep -q 'pre-psi'; then echo "HIT $f"; fi
done