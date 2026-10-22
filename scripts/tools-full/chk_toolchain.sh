set +e
which aarch64-linux-gnu-gcc aarch64-linux-gnu-ld aarch64-linux-gnu-objcopy 2>/dev/null
echo '--- python ---'; python3 -V
echo '--- repo tools ---'
ls /mnt/d/本地项目-01/_refs/ios-vermeer-lab/tools/
head -40 /mnt/d/本地项目-01/_refs/ios-vermeer-lab/tools/package_boot.py