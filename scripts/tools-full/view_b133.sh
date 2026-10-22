set +e
B=/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys133.sh
wc -l "$B"
sed -n '1,45p' "$B"