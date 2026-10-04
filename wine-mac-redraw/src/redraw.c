// redraw.exe - force Wine windows to repaint.
//
// Works around Wine's macOS driver leaving windows blank (white) after the
// display sleeps: the program is still running, but its windows are never
// asked to repaint, so there is nothing to see or click.
//
// usage: redraw.exe [title-substring]
//   no argument: repaint every visible top-level window in the Wine session
//   with an argument: only windows whose title contains it (case-insensitive)
#include <windows.h>
#include <shlwapi.h>
#include <stdio.h>
#include <string.h>

static const char *filter;
static int count;

static BOOL CALLBACK redraw_window(HWND hwnd, LPARAM lp) {
    char title[256] = "";
    if (!IsWindowVisible(hwnd)) return TRUE;
    GetWindowTextA(hwnd, title, sizeof title);
    if (filter && !StrStrIA(title, filter)) return TRUE;
    // Asynchronous: marks the window and all its children as needing a full
    // repaint; the owning program repaints on its next message loop pass.
    RedrawWindow(hwnd, NULL, NULL, RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_ALLCHILDREN);
    printf("repainted: \"%s\"\n", title);
    count++;
    return TRUE;
}

int main(int argc, char **argv) {
    filter = argc > 1 ? argv[1] : NULL;
    EnumWindows(redraw_window, 0);
    if (!count) { printf("no matching visible windows\n"); return 1; }
    return 0;
}
