#!/bin/bash
S=/mnt/d/本地项目-01/_k70port_extract/_upstream/UniXNU__uefi-sheng
echo "=== tree ==="
find "$S" -maxdepth 3 -type d | head -40
echo
echo "=== platform pkg files ==="
find "$S/Platforms" -maxdepth 3 -type f | head -40
echo
echo "=== Resources ==="
find "$S/Resources" -maxdepth 3 -type f | head -40
