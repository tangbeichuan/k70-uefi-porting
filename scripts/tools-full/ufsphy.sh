grep -n "ufsphy" /tmp/vb.dts | head -10
echo "----"
awk '/ufsphy@1d87000/,/^\t\t};/' /tmp/vb.dts | head -40