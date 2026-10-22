set +e
P=/mnt/d/本地项目-01/_k70port_extract/_upstream/UniXNU__UniXNU/drivers/NativeUfs
echo "=== GccUfs.h 全文 ==="
cat "$P/GccUfs.h"
echo "=== NativeUfs.cpp 里 GCC/clock 的用法 ==="
grep -nE 'GCC_|GDSCR|gccWrite|clockOn|enableUfs|Enable' "$P/NativeUfs.cpp" | head -25