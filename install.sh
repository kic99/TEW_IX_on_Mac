#!/bin/bash
# Installs Total Extreme Wrestling IX on an Apple Silicon Mac under Wine, following README.md.
#
# usage: bash install.sh <path to the TEW IX installer .msi>
#
# Everything goes in ~/tew9 (set TEW=... to change it). Details of every step go to
# ~/tew9/install.log. Safe to rerun after a failure: finished steps are skipped.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
TEW=${TEW:-$HOME/tew9}
APPS=${TEW_APP_DIR:-$HOME/Applications}
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/winetricks
STATE="$TEW/.install-state"
LOG="$TEW/install.log"

WINE_TAR=wine-staging-11.18-osx64.tar.xz
WINE_URL=https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.18/$WINE_TAR
WINE_SHA=b63704b91af269bc026a87f12bd297c4a50caaf570c322e600b6621ef918f127
WINE_APP="$TEW/wine/Wine Staging.app"
MDAC_URL="https://web.archive.org/web/20060718123742/http://ftp.gunadarma.ac.id/pub/driver/itegno/USB%20Software/MDAC/MDAC_TYP.EXE"
MDAC_SHA=36d2a3099e6286ae3fab181a502a95fbd825fa5ddb30bf09b345abc7f1f620b4
JET_URL="https://web.archive.org/web/20210225171713/http://download.microsoft.com/download/4/3/9/4393c9ac-e69e-458d-9f6d-2fe191c51469/Jet40SP8_9xNT.exe"
JET_SHA=b060246cd499085a31f15873689d5fa7df817e407c8261a5c71fa6b9f7042560
FIX="$HERE/wow64cpu-rosetta-fix"
FIX_DLL="$FIX/prebuilt/wine-11.18/wow64cpu.dll"
GAMEDIR_REL="drive_c/Program Files (x86)/Grey Dog Software/TEW9"

say() { printf '%s\n' "$*"; printf '\n=== %s  %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG" 2>/dev/null; }
die() {
    printf '\nERROR: %s\n' "$*"
    if [ -f "$LOG" ]; then
        printf '\nLast lines of the log (%s):\n' "$LOG"
        tail -n 15 "$LOG" | sed 's/^/  | /'
    fi
    printf '\nFix the problem above and run the same command again. Finished steps are skipped.\n'
    exit 1
}
# Run a command with its output going to the log; stop on failure.
run() { "$@" >>"$LOG" 2>&1 || die "this command failed: $*"; }
done_step() { [ -f "$STATE/$1" ]; }
mark() { touch "$STATE/$1"; }

# fetch <url> <file> <sha256>: download with retries unless the file is already there and correct.
fetch() {
    if [ -f "$2" ] && [ "$(shasum -a 256 "$2" | cut -d' ' -f1)" = "$3" ]; then return 0; fi
    mkdir -p "$(dirname "$2")"
    say "  downloading $(basename "$2") (this can be slow)"
    for try in 1 2 3 4 5; do
        rm -f "$2.part"
        if curl -fL --connect-timeout 30 --retry 3 --retry-delay 5 -o "$2.part" "$1" >>"$LOG" 2>&1; then
            if [ "$(shasum -a 256 "$2.part" | cut -d' ' -f1)" = "$3" ]; then mv "$2.part" "$2"; return 0; fi
            echo "checksum mismatch on try $try" >>"$LOG"
        fi
        [ $try -lt 5 ] && { say "  download failed, retrying in 15 seconds ($try of 5)"; sleep 15; }
    done
    rm -f "$2.part"
    die "could not download $(basename "$2") with the right checksum from $1
You can download it in a browser and put it at: $2"
}

# ---------------------------------------------------------------------------------------------
# Checks

MSI=${1:-}
if [ -n "$MSI" ]; then
    [ -f "$MSI" ] || { echo "Installer not found: $MSI"; exit 1; }
    MSI=$(cd "$(dirname "$MSI")" && pwd)/$(basename "$MSI")
fi
if [ -z "$MSI" ] && [ ! -f "$TEW/wineprefix/$GAMEDIR_REL/TEW9.exe" ]; then
    echo "usage: bash install.sh <path to the TEW IX installer .msi>"
    echo "  e.g. bash install.sh ~/Downloads/TEW9_Retail_Installer_142.msi"
    exit 1
fi

mkdir -p "$TEW" "$STATE" || exit 1
printf '\n##### install.sh started %s\n' "$(date)" >>"$LOG"
say "Installing TEW IX into $TEW"

[ "$(uname -m)" = arm64 ] || die "this script is for Apple Silicon Macs (M1 or newer)."
[ -f "$FIX_DLL" ] || die "the wow64cpu-rosetta-fix folder is missing. Keep install.sh in the folder you downloaded, next to wow64cpu-rosetta-fix."

if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    echo
    echo "Rosetta 2 is not installed. Wine needs it."
    printf 'Install it now? This runs: softwareupdate --install-rosetta --agree-to-license  [y/N] '
    ans=""; read -r ans
    case "$ans" in y|Y|yes|YES) softwareupdate --install-rosetta --agree-to-license || die "Rosetta install failed." ;;
        *) die "Rosetta 2 is required." ;; esac
    arch -x86_64 /usr/bin/true 2>/dev/null || die "Rosetta 2 still does not work."
fi

if ! command -v brew >/dev/null 2>&1; then
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi
command -v brew >/dev/null 2>&1 || die "Homebrew is not installed. Install it from https://brew.sh, then run this script again."

free_gb=$(df -k "$TEW" | awk 'NR==2 {print int($4/1048576)}')
[ "$free_gb" -ge 5 ] || die "not enough disk space: ${free_gb} GB free, about 5 GB needed."

if pgrep -qf 'Grey Dog Software.TEW9.'; then
    die "TEW IX is running. Quit it first."
fi

# ---------------------------------------------------------------------------------------------
# 1. Wine and winetricks

if ! command -v winetricks >/dev/null 2>&1 || ! command -v cabextract >/dev/null 2>&1; then
    say "Installing winetricks and cabextract with Homebrew"
    run brew install winetricks cabextract
fi

if ! done_step wine; then
    say "1. Wine 11.18"
    fetch "$WINE_URL" "$TEW/downloads/$WINE_TAR" "$WINE_SHA"
    rm -rf "$TEW/wine"; mkdir -p "$TEW/wine"
    run tar -xJf "$TEW/downloads/$WINE_TAR" -C "$TEW/wine"
    xattr -dr com.apple.quarantine "$WINE_APP" 2>/dev/null
    mark wine
fi

cat > "$TEW/tew-env.sh" <<EOF
export TEW="$TEW"
export PATH="\$TEW/wine/Wine Staging.app/Contents/Resources/wine/bin:\$PATH"
export WINEPREFIX="\$TEW/wineprefix"
export WINEDEBUG=-winediag
EOF
. "$TEW/tew-env.sh"
wine --version 2>>"$LOG" | grep -q 'wine-11.18' || die "Wine does not start (expected wine-11.18)."
GAMEDIR="$WINEPREFIX/$GAMEDIR_REL"

# ---------------------------------------------------------------------------------------------
# 2. Rosetta fix, 3. prefix

if ! done_step fix; then
    say "2. Rosetta fix (patched wow64cpu.dll)"
    (cd "$FIX/prebuilt/wine-11.18" && shasum -a 256 -c SHA256SUMS) >>"$LOG" 2>&1 || die "the prebuilt wow64cpu.dll fails its checksum."
    run sh "$FIX/install.sh" "$FIX_DLL" "$WINE_APP"
    mark fix
fi

if ! done_step prefix; then
    say "3. Creating the Wine prefix"
    run wineboot -u
    run wineserver -w
    mark prefix
fi
cmp -s "$WINEPREFIX/drive_c/windows/system32/wow64cpu.dll" "$FIX_DLL" \
    || run sh "$FIX/install.sh" "$FIX_DLL" "$WINE_APP" "$WINEPREFIX"
cmp -s "$WINEPREFIX/drive_c/windows/system32/wow64cpu.dll" "$FIX_DLL" || die "the Rosetta fix is not in the prefix."

# ---------------------------------------------------------------------------------------------
# 4. Libraries

if ! done_step mdac27; then
    say "4.1 MDAC 2.7"
    fetch "$MDAC_URL" "$CACHE/mdac27/MDAC_TYP.EXE" "$MDAC_SHA"
    for d in msado15 odbccp32 mtxdm odbc32 oledb32; do
        run wine reg add 'HKCU\Software\Wine\DllOverrides' /v "*$d" /t REG_SZ /d native,builtin /f
    done
    rm -rf "$WINEPREFIX/drive_c/windows/temp/mdac27x"
    run cabextract -q -d "$WINEPREFIX/drive_c/windows/temp/mdac27x" "$CACHE/mdac27/MDAC_TYP.EXE"
    run winetricks -q -f nt40
    (cd "$WINEPREFIX/drive_c/windows/temp/mdac27x" && wine setup.exe /qnt) >>"$LOG" 2>&1 || die "MDAC setup failed."
    run wineserver -w
    [ -f "$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ADO/msado26.tlb" ] || die "MDAC did not install (msado26.tlb missing)."
    mark mdac27
fi

if ! done_step jet40; then
    say "4.2 WSH 5.7 and Jet 4.0"
    run winetricks -q -f wsh57
    fetch "$JET_URL" "$CACHE/jet40/jet40sp8_9xnt.exe" "$JET_SHA"
    run wine "$CACHE/jet40/jet40sp8_9xnt.exe" /q
    run wineserver -w
    [ -f "$WINEPREFIX/drive_c/windows/syswow64/msjet40.dll" ] || die "Jet 4.0 did not install (msjet40.dll missing)."
    run winetricks -q win10
    for v in mdac27 jet40; do
        grep -qx "$v" "$WINEPREFIX/winetricks.log" 2>/dev/null || echo "$v" >> "$WINEPREFIX/winetricks.log"
    done
    mark jet40
fi

if ! done_step libs; then
    say "4.3 VB6 runtime, oleaut32, .NET 4.8 (about 5 minutes plus downloads)"
    run wine reg add 'HKCU\Software\Wine\DllOverrides' /v mscorsvw.exe /d "" /f
    run winetricks -q -f vb6run native_oleaut32 dotnet48
    run wineserver -w
    sys="$WINEPREFIX/drive_c/windows/syswow64"
    [ -f "$sys/msvbvm60.dll" ] || die "the VB6 runtime did not install."
    [ "$(stat -f %z "$sys/oleaut32.dll")" = 598288 ] || die "the native oleaut32.dll did not install."
    wine reg query 'HKLM\Software\Microsoft\NET Framework Setup\NDP\v4\Full' /v Release 2>>"$LOG" | grep -q 0x80eb1 \
        || die ".NET 4.8 did not install."
    mark libs
fi

# ---------------------------------------------------------------------------------------------
# 5. The game

if [ ! -f "$GAMEDIR/TEW9.exe" ]; then
    say "5. Installing the game from $(basename "$MSI")"
    MSIWIN=$(wine winepath -w "$MSI" 2>/dev/null)
    printf '@echo off\r\nmsiexec /i "%s" /qn APPDIR="C:\\Program Files (x86)\\Grey Dog Software\\TEW9\\"\r\necho MSIEXIT=%%ERRORLEVEL%%\r\n' \
        "$MSIWIN" > "$TEW/install_tew9.bat"
    out=$(wine cmd /c "$(wine winepath -w "$TEW/install_tew9.bat" 2>/dev/null)" 2>>"$LOG")
    echo "$out" >>"$LOG"
    run wineserver -w
    echo "$out" | grep -q 'MSIEXIT=0' || die "the game installer failed ($(echo "$out" | grep MSIEXIT | tr -d '\r'))."
    [ -f "$GAMEDIR/TEW9.exe" ] || die "the game installer finished but TEW9.exe is missing."
fi

# ---------------------------------------------------------------------------------------------
# 6. Launcher

say "6. Launcher"
cat > "$TEW/tew9.sh" <<'EOF'
#!/bin/zsh
# Launch TEW9. Keeps the display awake while playing, and ends the game once it and the
# License Wizard have had no windows for 30 seconds (after quitting, the game can linger).
. "${0:A:h}/tew-env.sh"
GAME='Grey Dog Software.TEW9.TEW9\.exe'
ALL='Grey Dog Software.TEW9.'   # the game and its separate License Wizard
cd "$WINEPREFIX/drive_c/Program Files (x86)/Grey Dog Software/TEW9" || exit 1
pgrep -qf "$GAME" && { echo "TEW9 is already running"; exit 0; }
caffeinate -d -w $$ &
wine TEW9.exe "$@" &
pid=""
for i in {1..30}; do sleep 2; pid=$(pgrep -f "$GAME" | head -1); [ -n "$pid" ] && break; done
if [ -n "$pid" ]; then
  seen=0; gone=0; waited=0
  while kill -0 $pid 2>/dev/null; do
    sleep 5; waited=$((waited+5))
    if [ "$(osascript -l JavaScript "$TEW/winewindows.js" $(pgrep -f "$ALL"))" -gt 0 ]; then seen=1; gone=0; else gone=$((gone+5)); fi
    # Gone for 30 s and idle (not still writing the save on quit).
    [ $seen = 1 ] && [ $gone -ge 30 ] && [ "$(ps -o %cpu= -p $pid | cut -d. -f1)" -lt 2 ] && break
    [ $seen = 0 ] && [ $waited -ge 300 ] && break
  done
fi
# End only the game and the wizard, so other programs in the prefix keep running.
if pgrep -qf "$ALL"; then
  wine taskkill /f /im TEW9.exe /im QlmLicenseWizard.exe >/dev/null 2>&1
  sleep 3; pkill -9 -f "$ALL"
fi
EOF

cat > "$TEW/winewindows.js" <<'EOF'
// usage: osascript -l JavaScript winewindows.js <pid> [<pid> ...]
// Prints how many real windows belong to the given processes. Uses only owner PID and size,
// which macOS gives without Screen Recording permission. Skips VB6's hidden 1x1 window and
// Wine's off-screen 500x500 helper windows. From https://github.com/Philsmith1/wmma6-on-mac
ObjC.import('CoreGraphics');
function run(argv) {
  var pids = argv.map(function (p) { return parseInt(p, 10); });
  var list = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo($.kCGWindowListOptionAll, 0))) || [];
  var n = 0;
  list.forEach(function (w) {
    if (pids.indexOf(w.kCGWindowOwnerPID) < 0 || w.kCGWindowLayer !== 0) return;
    var b = w.kCGWindowBounds;
    if (b.Width <= 50 || b.Height <= 50) return;
    if (!w.kCGWindowIsOnscreen && b.Width === 500 && b.Height === 500) return;
    n++;
  });
  return String(n);
}
EOF
chmod +x "$TEW/tew9.sh"

# A TEW9.app so the game can be started from Finder, Launchpad or Spotlight.
mkdir -p "$APPS"
rm -rf "$APPS/TEW9.app"
osacompile -o "$APPS/TEW9.app" \
    -e "do shell script quoted form of \"$TEW/tew9.sh\" & \" >/dev/null 2>&1 &\"" >>"$LOG" 2>&1 \
    || die "could not create $APPS/TEW9.app"

say ""
say "Done. TEW IX is installed."
say ""
say "Start it with TEW9 in $APPS (or Spotlight: type TEW9),"
say "or from Terminal with: $TEW/tew9.sh"
say ""
say "On first launch the License Wizard opens after 10 to 20 seconds. Click"
say "Activate your license, enter your key, and activate online."
