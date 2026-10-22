set +e
grep -nE "probe moved|probe not in APRIORI|apriori" /tmp/k88.log | head -5
echo "--- guid check ---"
grep -iE 'VermeerKeyProbeDxe|VermeerUfsMapDxe' /tmp/guid-keys88.xref 2>/dev/null | head -4