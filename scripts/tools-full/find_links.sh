set +e
S=/mnt/c/Users/QWQ/.dsh/sessions/--D-~672C~5730~9879~76EE-01--/session-2c7fe31c-7d0e-44b3-bdd0-1446984961af/session.v4.jsonl.zstd
ls -l "$S"
zstd -dc "$S" 2>/dev/null | grep -o 'https\?://[^"\\ ]*' | sed 's/[),.]$//' | sort | uniq -c | sort -rn | head -40