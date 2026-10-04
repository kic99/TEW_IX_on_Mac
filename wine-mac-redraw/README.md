# wine-mac-redraw: repaint blank Wine windows on macOS

A tiny Windows program that makes every window in a running Wine session repaint itself.

It works around a Wine macOS driver bug. After the Mac's display sleeps and wakes, a Wine program's windows can come back **blank white**, often with one or two controls still showing. The program is still running normally. Its windows were just never asked to repaint. With nothing visible, you can't click anything or close dialogs, so the only way out used to be force-quitting and losing unsaved progress.

Seen with Total Extreme Wrestling IX on Gcenx Wine 11.18 Staging, macOS 27.0.1 (Apple Silicon). It should work with any Wine program.

## Contents

| Path | What it is |
|---|---|
| `prebuilt/redraw.exe` | Ready-to-use 64-bit Windows program (see `SHA256SUMS`) |
| `redraw.sh` | Runs it in your prefix |
| `src/redraw.c` | Source |
| `build.sh` | Rebuilds `prebuilt/redraw.exe` from source |

## Use

While the program is still running with its blank window, open Terminal and run:

```sh
WINEPREFIX=/path/to/your/prefix ./redraw.sh
```

Every visible window in that Wine session repaints straight away. To repaint only some windows, pass part of a window title (case doesn't matter):

```sh
WINEPREFIX=/path/to/your/prefix ./redraw.sh "TEW IX"
```

It prints each window it repainted. It exits with status 1 if no window matched.

If `wine` is not on your `PATH`, point `WINE` at it:

```sh
WINE="/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine" \
WINEPREFIX=/path/to/your/prefix ./redraw.sh
```

Without the script: `wine /path/to/redraw.exe` with the same `WINEPREFIX`.

It is safe to run at any time. It only asks windows to repaint. It doesn't click, type, move or close anything, and it changes no files.

### Avoiding it

The bug only happens when the display sleeps. To keep the display awake only while the program runs, start it through macOS's `caffeinate`:

```sh
caffeinate -d wine YourProgram.exe
```

## Build

```sh
brew install mingw-w64
./build.sh
```

This rebuilds `prebuilt/redraw.exe` and `SHA256SUMS`.

## How it works

`redraw.exe` lists every top-level window in the Wine session (`EnumWindows`). For each visible one it calls:

```c
RedrawWindow(hwnd, NULL, NULL, RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_ALLCHILDREN);
```

This marks the window, its frame and all its child controls as needing a full repaint. The owning program then repaints everything on its next pass through its message loop. The call is asynchronous, so a busy or hung program cannot block `redraw.exe`.

All Wine programs in a prefix share one window manager (`wineserver`), so a separate program can do this for another program's windows.

## Licence

The source, scripts and binary may be used freely.
