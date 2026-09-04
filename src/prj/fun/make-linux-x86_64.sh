#!/bin/sh
# ============================================================
# Fun - 64-bit (x86_64) Linux console build of funcmd.dpr
#
# Counterpart of make-linux.bat (which cross-compiles i386 from a
# Windows-hosted FPC). This builds a native x86_64-linux interpreter.
#
# Usage:
#   ./make-linux-x86_64.sh            # FPC resolved from PATH
#   FPC=/path/to/fpc ./make-linux-x86_64.sh
#
# Extra FPC switches can be appended, e.g.:
#   ./make-linux-x86_64.sh -dCalcOpt
#
# Note: regex is NOT enabled here. make-*.bat pass "-dRegexx" but the source
# gates regex on {$IfDef Regex} (one word), so "-dRegexx" is a no-op and regex
# stays compiled out. Enabling -dRegex would need the Windows/MSVCRT-bound PCRE
# linkage, which is a separate Linux port.
# ============================================================
set -e
cd "$(dirname "$0")"

# Resolve the Free Pascal driver. FPC env var wins, else PATH, else a
# few common locations.
if [ -n "$FPC" ]; then
    FPC_BIN="$FPC"
elif command -v fpc >/dev/null 2>&1; then
    FPC_BIN="$(command -v fpc)"
elif [ -x /usr/bin/fpc ]; then
    FPC_BIN=/usr/bin/fpc
elif [ -x "$HOME/fpc-3.2.2/bin/fpc" ]; then
    FPC_BIN="$HOME/fpc-3.2.2/bin/fpc"
else
    echo "Free Pascal not found. Set FPC=<path-to-fpc-bin>." >&2
    exit 1
fi

# fpcres (resource compiler) must be reachable for the {$R *.res} file.
FPC_BINDIR="$(dirname "$FPC_BIN")"
export PATH="$FPC_BINDIR:$PATH"

echo "Building funcmd with $FPC_BIN"
"$FPC_BIN" funcmd.dpr -B -Sd -O2 -Xs -Tlinux -dLinux "$@"
