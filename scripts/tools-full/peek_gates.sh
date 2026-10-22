set +e
G=/mnt/d/本地项目-01/_k70port_extract/wsl/gates.py
ls -l "$G"; wc -l "$G"
echo "=== subcommands / main ==="
grep -n "sys.argv\|def main\|elif cmd\|if cmd\|def cmd_\|APRIORI\|\[Components\]" "$G" | head -40
echo "=== keyprobe section ==="
grep -n -A25 "def .*keyprobe\|'keyprobe'\|\"keyprobe\"" "$G" | head -60