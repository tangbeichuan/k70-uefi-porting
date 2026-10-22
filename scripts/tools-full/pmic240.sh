set +e
sed -n "/1e240:/,/1e2dc:/p" /tmp/pmic.asm | head -30