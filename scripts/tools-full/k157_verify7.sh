#!/usr/bin/env bash
set -e
sed -n '/ 21c0:/,/ 2400:/p' /tmp/dtb157.asm
