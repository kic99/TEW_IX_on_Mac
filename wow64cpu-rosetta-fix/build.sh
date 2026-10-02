#!/bin/sh
# Build the Rosetta-patched wow64cpu.dll for a Gcenx/upstream Wine install.
#
# usage: ./build.sh <wine-version> <path to "Wine Staging.app" (or Wine Devel.app)>
#   e.g. ./build.sh 11.18 ~/tew9/wine/"Wine Staging.app"
#
# needs: brew install mingw-w64   (x86_64-w64-mingw32-gcc, dlltool, objdump)
# output: out/wine-<version>/wow64cpu.dll
set -eu
VER=${1:?wine version, e.g. 11.18}
APP=${2:?path to the Wine .app bundle}
HERE=$(cd "$(dirname "$0")" && pwd)
LIB="$APP/Contents/Resources/wine/lib/wine/x86_64-windows"
WORK="$HERE/work/wine-$VER"; OUT="$HERE/out/wine-$VER"
CC=x86_64-w64-mingw32-gcc; DLLTOOL=x86_64-w64-mingw32-dlltool; OBJDUMP=x86_64-w64-mingw32-objdump
command -v $CC >/dev/null || { echo "missing $CC: brew install mingw-w64"; exit 1; }
[ -f "$LIB/ntdll.dll" ] || { echo "no Wine DLLs at $LIB"; exit 1; }
mkdir -p "$WORK" "$OUT"

# 1. Wine source: headers + dlls/wow64cpu
MAJOR=${VER%%.*}
if [ ! -d "$WORK/wine-$VER/include" ]; then
    curl -fL -o "$WORK/wine.tar.xz" "https://dl.winehq.org/wine/source/$MAJOR.x/wine-$VER.tar.xz"
    tar -xJf "$WORK/wine.tar.xz" -C "$WORK" "wine-$VER/include" "wine-$VER/dlls/wow64cpu" "wine-$VER/COPYING.LIB"
    rm "$WORK/wine.tar.xz"
fi
SRC="$WORK/wine-$VER"

# 2. apply the patch (to a copy, so reruns are clean)
cp "$SRC/dlls/wow64cpu/cpu.c" "$WORK/cpu.c"
patch -s "$WORK/cpu.c" "$HERE/wow64cpu-rosetta-farjump.patch"

# 3. import libraries from the installed Wine's own ntdll.dll / wow64.dll
for d in ntdll wow64; do
    { echo "LIBRARY $d.dll"; echo EXPORTS
      $OBJDUMP -p "$LIB/$d.dll" | awk '/\[Ordinal\/Name Pointer\] Table/{f=1;next} f&&/\+base\[/{print $NF}'; } > "$WORK/$d.def"
    $DLLTOOL -d "$WORK/$d.def" -l "$WORK/lib$d.a"
done
sed -n 's/^@ stdcall \(-norelay \)\{0,1\}\([A-Za-z_0-9]*\)(.*/\2/p' "$SRC/dlls/wow64cpu/wow64cpu.spec" \
    | { echo "LIBRARY wow64cpu.dll"; echo EXPORTS; cat; } > "$WORK/wow64cpu.def"

# 4. compile + link (same image base as Wine's build)
GCCINC=$($CC -print-file-name=include)
$CC -c -O2 -nostdinc -isystem "$GCCINC" -I"$SRC/include" -I"$SRC/include/msvcrt" \
    -D__WINESRC__ -D__WINE_PE_BUILD -D_NO_CRT_STDIO_INLINE -DWINE_NO_LONG_TYPES -D_WIN32_WINNT=0x0a00 \
    -fno-strict-aliasing -fasynchronous-unwind-tables -Wall -Wno-unused \
    -o "$WORK/cpu.o" "$WORK/cpu.c"
$CC -shared -nostdlib -o "$OUT/wow64cpu.dll" "$WORK/cpu.o" "$WORK/wow64cpu.def" \
    -L"$WORK" -lwow64 -lntdll -Wl,--image-base,0x7a400000 -Wl,-e,DllMain

# 5. mark it as a Wine builtin DLL: "Wine builtin DLL" + NUL at offset 0x40, as winebuild does
#    (wineboot only copies DLLs with the NUL-terminated signature into new prefixes)
printf 'Wine builtin DLL\000' | dd of="$OUT/wow64cpu.dll" bs=1 seek=64 conv=notrunc 2>/dev/null

shasum -a 256 "$OUT/wow64cpu.dll"
echo "built $OUT/wow64cpu.dll"
