set +e
head -20 /mnt/d/本地项目-01/_k70port_extract/wsl/gates.py | grep -n "^import"
python3 -c "import ast,sys; ast.parse(open('/mnt/d/本地项目-01/_k70port_extract/wsl/gates.py').read()); print('syntax OK')"