#!/bin/bash
set -e
mkdir -p "/mnt/d/本地项目-01/_refs"
cd "/mnt/d/本地项目-01/_refs"
rm -rf ios-vermeer-lab
timeout 600 git clone --depth 1 https://github.com/xyyyds0106/ios-vermeer-lab.git 2>&1 | tail -5
echo "--- top level ---"
ls -la ios-vermeer-lab | head -25
echo "--- size ---"
du -sh ios-vermeer-lab