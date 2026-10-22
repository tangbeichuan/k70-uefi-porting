#!/usr/bin/env bash
bash /mnt/d/本地项目-01/_tools/run154.sh > /mnt/d/本地项目-01/_tools/b154_wrap.log 2>&1
echo "RC=$?"
tail -45 /mnt/d/本地项目-01/_tools/b154_wrap.log
