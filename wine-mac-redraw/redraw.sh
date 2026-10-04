#!/bin/sh
# Repaint blank Wine windows (e.g. after the Mac display slept).
#
# usage: WINEPREFIX=/path/to/prefix ./redraw.sh [title-substring]
#   Set WINE to your wine binary if `wine` is not on PATH, e.g.
#   WINE="/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine"
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
: "${WINEPREFIX:?set WINEPREFIX to the prefix the program is running in}"
export WINEPREFIX
WINE=${WINE:-wine}
command -v "$WINE" >/dev/null || { echo "wine not found: set WINE to your wine binary"; exit 1; }
WINEDEBUG=-all exec "$WINE" "$HERE/prebuilt/redraw.exe" "$@"
