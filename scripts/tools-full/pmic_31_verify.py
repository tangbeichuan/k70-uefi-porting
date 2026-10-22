#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verify PmicDxe DTBExtn property requirements against xbl_ufs.dtb (via .dts). v2"""
import subprocess, re, os

DTB = "/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb"
DTS = "/tmp/xbl_ufs.dts"
if not os.path.exists(DTS):
    subprocess.run(["dtc", "-I", "dtb", "-O", "dts", DTB, "-o", DTS], check=True)

lines = open(DTS, encoding="utf-8", errors="replace").read().splitlines()

nodes = {}
node_props = {}
stack = []
for ln in lines:
    raw = ln.rstrip()
    if not raw.strip() or raw.strip().startswith("//") or raw.strip().startswith("/*"):
        continue
    ind = len(raw) - len(raw.lstrip())
    m = re.match(r"^(\s*)([A-Za-z0-9_,.\-+@]+)\s*\{\s*$", raw)
    if m:
        name = m.group(2)
        while stack and stack[-1][0] >= ind:
            stack.pop()
        path = "/" if name == "/" else ((stack[-1][1].rstrip("/") + "/" + name) if stack else "/" + name)
        stack.append((ind, path))
        nodes.setdefault(path, {})
        continue
    if raw.strip() == "};":
        while stack and stack[-1][0] >= ind:
            stack.pop()
        continue
    m = re.match(r"^(\s*)([A-Za-z0-9_,.\-+#]+)\s*(?:=\s*(.*?))?;\s*$", raw)
    if m and stack:
        prop = m.group(2)
        val = (m.group(3) or "").strip()
        nodes.setdefault(stack[-1][1], {})[prop] = val

def classify(v):
    if v is None:
        return None
    s = v.strip()
    if s == "":
        return "bool"
    if s.startswith('"'):
        return "str"
    if re.match(r"^<[^>]*>$", s):
        return "list"
    return "other"

V = "/sw/pmic/adc/vadc/spmi-vadc@7"
REQ = []
def add(path, prop, kind, note):
    REQ.append((path, prop, kind, note))

# ---- VADC device node (0x1f114) ----
add(V, "use-interrupt", "list1", "+0x88 -> blob+0x56")
for p in ("fullscale-code", "fullscale-uV", "fullratiometric-code", "read-timeout-uS",
          "ldo-settling-uS", "slave-id", "peripheral-id", "master-id"):
    add(V, p, "list1", "+0xa0 -> blob")
add(V, "pmic-device", "list1", "+0xa0 -> blob+0x55")
add(V, "bus-id", "list1", "+0xa0 -> blob+0x54")
add(V, "gpio-map", "node", "+0x30 GetNode; +0x28 count<=0x28; +0x68/+0x70 names")
add(V, "therm_table", "node", "+0x30 GetNode; +0x28 count<=0xa")
add(V, "vadc_ch_cfg", "node", "+0x30 GetNode; +0x28 count<=0x64")
for g in ("aux_pin1", "aux_pin2"):
    add(V + "/gpio-map/" + g, "gpio-num", "list1", "+0xa0 -> entry+0xc")
    add(V + "/gpio-map/" + g, "pmic-sid", "list1", "+0xa0 -> entry+0x10")
for t in ("therm_tb@1", "therm_tb@2"):
    add(V + "/therm_table/" + t, "reg", "list1", "+0xa0")
    add(V + "/therm_table/" + t, "table", "list", "+0x90 len / +0x98 +0xa8 data")
# ---- vadc channels (0x1e7bc) ----
CH = [("hw-channel", "list1"), ("settling-delay-uS", "list1"), ("average-sample", "list1"),
      ("decimation-ratio", "list1"), ("cal-method", "str"), ("scaling-factor", "list"),
      ("scaling-method", "str"), ("offset-factor", "list"), ("pull-up-res", "list1"),
      ("adc-sid", "list1"), ("int-table", "anystr")]
chans = sorted(k for k in nodes if re.match(re.escape(V + "/vadc_ch_cfg/") + r"[^/]+$", k))
for c in chans:
    for p, k in CH:
        add(c, p, k, "0x1e7bc")

print("vadc_ch_cfg children: %d" % len(chans))
print()
print("%-42s %-22s %-8s %-8s %s" % ("NODE", "PROP", "KIND", "STATUS", "VALUE"))
print("-" * 132)
bad = 0
rows = []
for path, prop, kind, note in REQ:
    exists = path in nodes
    v = nodes.get(path, {}).get(prop)
    if kind == "node":
        have = (path + "/" + prop) in nodes
        st = "NODE-OK" if have else ("NODE-MISS" if exists else "PATH-MISS")
        shown = ""
    elif prop not in nodes.get(path, {}):
        st = "PATH-MISS" if not exists else "PROP-MISS"
        shown = ""
    else:
        c = classify(v)
        if kind == "list1":
            ok = c == "list" and len(re.findall(r"<[0-9a-fA-Fx]+>", v)) == 1
            st = "OK" if ok else "TYPE(%s)" % c
        elif kind == "list":
            ok = c == "list"
            st = "OK" if ok else "TYPE(%s)" % c
        elif kind == "str":
            st = "OK" if c == "str" else "TYPE(%s)" % c
        elif kind == "anystr":
            st = "OK" if c in ("bool", "str") else "TYPE(%s)" % c
        else:
            st = "?"
        shown = str(v)[:46]
    if not st.endswith("OK"):
        bad += 1
    rows.append((path, prop, kind, st, shown, note))
    print("%-42s %-22s %-8s %-9s %s" % (path.replace(V, "…"), prop, kind, st, shown))
print()
print("TOTAL=%d  PROBLEMS=%d  nodes=%d" % (len(REQ), bad, len(nodes)))
print("channels:", ", ".join(c.split("/")[-1] for c in chans))
