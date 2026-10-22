#!/usr/bin/env bash
# Authoritative module list: every EDK2 module compiles its own AutoGen.c, so the
# directories that produced AutoGen.obj are exactly the modules in this build.
set +e
LOG=/root/k70/build-default.log
grep -oE 'AARCH64/[^ ]*/OUTPUT/(\./)?AutoGen\.obj' "$LOG" | sed -E 's#AARCH64/##; s#/OUTPUT/.*##' | awk -F/ '{print $NF}' | sort -u > /tmp/autogen.txt
echo "modules in the default (Mu-only) build: $(wc -l < /tmp/autogen.txt)"
tr '\n' ' ' < /tmp/autogen.txt; echo

VLOG=/root/k70/build-vendorhw.log
grep -oE 'AARCH64/[^ ]*/OUTPUT/(\./)?AutoGen\.obj' "$VLOG" | sed -E 's#AARCH64/##; s#/OUTPUT/.*##' | awk -F/ '{print $NF}' | sort -u > /tmp/autogen_v.txt
echo
echo "modules in the vendor-hardware build: $(wc -l < /tmp/autogen_v.txt)"
echo
echo "extra modules that only appear with VERMEER_VENDOR_HW=1: $(comm -13 /tmp/autogen.txt /tmp/autogen_v.txt | wc -l)"
comm -13 /tmp/autogen.txt /tmp/autogen_v.txt | tr '\n' ' '; echo
echo
echo "modules missing from the vendor build vs default: $(comm -23 /tmp/autogen.txt /tmp/autogen_v.txt | wc -l)"
comm -23 /tmp/autogen.txt /tmp/autogen_v.txt | tr '\n' ' '; echo
