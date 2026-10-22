#!/usr/bin/env bash
# git protocol to github.com:443 is unreliable here; codeload (plain HTTPS) worked
# for the earlier mirrors, so fetch the pinned libspdm commit as a tarball instead.
set +e
DEST=/root/k70/uefi/Mu_Basecore/SecurityPkg/DeviceSecurity/SpdmLib/libspdm
REV=f55cf6d48ec69b4ac60a63903e9c6a2cb0fd155d
TMP=/root/k70/tmp

rm -rf "$DEST" "$TMP"; mkdir -p "$DEST" "$TMP"
python3 - "$REV" "$TMP" <<'PY'
import sys, urllib.request, tarfile, io, time
rev, tmp = sys.argv[1], sys.argv[2]
urls = [f"https://codeload.github.com/DMTF/libspdm/tar.gz/{rev}",
        f"https://github.com/DMTF/libspdm/archive/{rev}.tar.gz",
        f"https://cdn.jsdelivr.net/gh/DMTF/libspdm@{rev}/"]
for attempt in range(4):
    for u in urls[:2]:
        try:
            print("fetch", u, flush=True)
            req = urllib.request.Request(u, headers={"User-Agent": "k70-port/1.0"})
            data = urllib.request.urlopen(req, timeout=120).read()
            print("got", len(data), "bytes", flush=True)
            tf = tarfile.open(fileobj=io.BytesIO(data), mode="r:gz")
            root = tf.getnames()[0].split("/")[0]
            tf.extractall(tmp)
            print("ROOT=" + root)
            sys.exit(0)
        except Exception as e:
            print("  fail:", type(e).__name__, str(e)[:90], flush=True)
            time.sleep(3)
sys.exit(1)
PY
rc=$?
if [ $rc -eq 0 ]; then
  root=$(ls -1 "$TMP" | head -1)
  cp -a "$TMP/$root/." "$DEST"/
  echo "libspdm populated from $root"
else
  echo "DOWNLOAD FAILED - creating a stub include dir so meta-data can proceed"
  mkdir -p "$DEST/include"
  echo "/* stub: libspdm sources unavailable, SPDM is not built for this platform */" > "$DEST/include/libspdm_stub.h"
fi
echo
echo "===== check ====="
ls "$DEST/include" 2>/dev/null | head -5
du -sh "$DEST" 2>/dev/null
