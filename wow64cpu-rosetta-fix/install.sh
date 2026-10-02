#!/bin/sh
# Install the patched wow64cpu.dll into a Wine install AND an existing prefix (if given).
# Wine loads wow64cpu from the PREFIX (C:\windows\system32), and wineboot copies it there
# from the Wine install, so both copies must be replaced.
#
# usage: ./install.sh <wow64cpu.dll> <path to Wine .app> [WINEPREFIX]
set -eu
DLL=${1:?patched wow64cpu.dll}; APP=${2:?path to Wine .app}; PFX=${3:-}
LIBDLL="$APP/Contents/Resources/wine/lib/wine/x86_64-windows/wow64cpu.dll"
[ -f "$LIBDLL" ] || { echo "not found: $LIBDLL"; exit 1; }
[ -f "$LIBDLL.orig" ] || cp -p "$LIBDLL" "$LIBDLL.orig"
cp "$DLL" "$LIBDLL"; echo "installed into Wine: $LIBDLL (original kept as .orig)"
if [ -n "$PFX" ]; then
    SYSDLL="$PFX/drive_c/windows/system32/wow64cpu.dll"
    [ -f "$SYSDLL" ] || { echo "not found: $SYSDLL (run wineboot first)"; exit 1; }
    [ -f "$SYSDLL.orig" ] || cp -p "$SYSDLL" "$SYSDLL.orig"
    cp "$DLL" "$SYSDLL"; echo "installed into prefix: $SYSDLL (original kept as .orig)"
fi
