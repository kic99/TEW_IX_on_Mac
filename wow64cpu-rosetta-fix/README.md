# wow64cpu Rosetta fix for Wine on Apple Silicon

A patched `wow64cpu.dll` that lets **32-bit .NET programs** run under Wine's WoW64 mode on Apple Silicon Macs (Rosetta 2).

Without it, any 32-bit .NET Framework or Wine Mono program hangs at startup with:

```
err:virtual:virtual_setup_exception nested exception on signal stack
```

This blocks, for example, the QLM licence manager used by Total Extreme Wrestling IX (retail).

Tested with Gcenx Wine 11.18 Staging on macOS 27.0.1 (M5 Max). Wine 11.0 through 11.18 all have the bug.

## Contents

| Path | What it is |
|---|---|
| `prebuilt/wine-11.18/wow64cpu.dll` | Ready-to-use DLL for Wine 11.18 (see `SHA256SUMS`) |
| `wow64cpu-rosetta-farjump.patch` | The change, against Wine 11.18 `dlls/wow64cpu/cpu.c` |
| `src/cpu.c` | The full patched source file |
| `build.sh` | Downloads the Wine source, applies the patch, builds the DLL |
| `install.sh` | Installs the DLL into a Wine `.app` and, optionally, an existing prefix |
| `test/exc.cs` | A small C# test program |
| `COPYING.LIB` | Wine's licence (LGPL 2.1) |

## Install

Install it **before** creating the prefix. `wineboot` then copies it into the prefix for you:

```sh
./install.sh prebuilt/wine-11.18/wow64cpu.dll "/path/to/Wine Staging.app"
```

For an **existing** prefix, also pass the prefix path:

```sh
./install.sh prebuilt/wine-11.18/wow64cpu.dll "/path/to/Wine Staging.app" "$WINEPREFIX"
```

Wine loads `wow64cpu.dll` from the prefix (`drive_c/windows/system32/`), not from the `.app`. Prefix updates by `wineboot` copy the `.app`'s version over the prefix's copy. So both copies must be patched. The script keeps the originals as `wow64cpu.dll.orig`.

To undo, copy the `.orig` files back.

## Build (any Wine version)

The prebuilt DLL matches Wine 11.18. For another version, build it:

```sh
brew install mingw-w64
./build.sh <wine-version> "/path/to/Wine Staging.app"
# output: out/wine-<version>/wow64cpu.dll
```

The patch is small and applies to Wine versions with the same `cpu.c` layout. If it doesn't apply, make the same edits by hand (see below).

## Test

Build the test program with the C# compiler that comes with .NET 4.x in the prefix, then run it:

```sh
wine 'C:\windows\Microsoft.NET\Framework\v4.0.30319\csc.exe' /nologo /platform:x86 /out:exc32.exe test/exc.cs
wine exc32.exe
```

Expected output:

```
start, 64bit=False clr=4.0.30319.42000
caught managed: managed
caught nullref: NullReferenceException
done
```

Without the fix, it prints nothing and hangs.

## What the patch changes

Wine's WoW64 runs 32-bit code inside a 64-bit process. `wow64cpu.dll` switches the CPU between 32-bit and 64-bit mode on every system call. Upstream Wine uses far **jumps** for that: `ljmp *m16:32` in both directions.

Under Rosetta 2, these far jumps sometimes do not switch the mode. The 64-bit thunk `syscall_32to64` then runs as 32-bit code and faults. The faulting instruction reads `cs32_sel` relative to RIP; decoded as 32-bit code it reads absolute address `0x2EC5` instead. Wine's signal handler then gets a 32-bit context in a 64-bit handler and fails with "nested exception on signal stack". The process hangs.

The patch replaces both far jumps with far **returns**:

- **32→64 entry thunk** (built in `BTCpuProcessInit`): `push $cs64; push $target; lret` instead of `ljmp *[ptr]`.
- **64→32 return** (`syscall_32to64` and `unix_call_32to64`): push `Eip`/`SegCs` and `lretq` instead of `ljmp *(%r14)`.

Both directions are needed. Fixing only the return path still fails 5 of 5 runs. A direct `ljmp ptr16:32` entry also fails.

Most 32-bit programs (for example a VB6 game) never hit this. .NET's JIT runtime does, every time.

Prior art: Sikarugir's Wine fork ships a `wow64cpu.dll` with a similar `syscall_32to64_rosetta2_workaround`. It is enabled when the CPU brand string contains "VirtualApple", and it uses `lcall`/`lretq`. This patch applies the same idea unconditionally to upstream Wine 11.18.

## Licence

Wine, including `dlls/wow64cpu/cpu.c`, is licensed under the GNU LGPL 2.1 or later (`COPYING.LIB`). The patched source and the patch are included here, as the LGPL requires when distributing the modified DLL. The scripts and test program in this folder may be used freely.
