#!/bin/sh
# Rebuild prebuilt/redraw.exe from src/redraw.c.
# needs: brew install mingw-w64
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
CC=x86_64-w64-mingw32-gcc
command -v $CC >/dev/null || { echo "missing $CC: brew install mingw-w64"; exit 1; }
$CC -O2 -s -Wall -o "$HERE/prebuilt/redraw.exe" "$HERE/src/redraw.c" -luser32 -lshlwapi
(cd "$HERE/prebuilt" && shasum -a 256 redraw.exe > SHA256SUMS)
echo "built: $HERE/prebuilt/redraw.exe"
