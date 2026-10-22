set +e
cd /mnt/d/????-01/_k70port_extract/port-drivers
for f in VermeerKeyProbeDxe/VermeerKeyProbeDxe.c VermeerDtDumpDxe/VermeerDtDumpDxe.c VermeerDtbExtnDxe/VermeerDtbExtnDxe.c; do
  if [ -f "$f" ]; then
    echo "--- $f"
    grep -oE 'DEBUG \(\s*\(?DEBUG_[A-Z]+' "$f" | sort | uniq -c
  fi
done