#!/bin/sh
# ============================================================
# Fun - 64-bit (x86_64) Linux console build of funcmd.dpr
#
# Counterpart of make-linux.bat (which cross-compiles i386 from a
# Windows-hosted FPC). This builds a native x86_64-linux interpreter.
#
# It also builds the bundled PCRE 8 engine (8-bit) from the vendored C
# source under src/3rd/pcre-8 and enables regex (-dRegex, one word - the
# "-dRegexx" used by the .bat scripts is a no-op typo). If the PCRE C
# source is not present, the build falls back to regex-disabled.
#
# Usage:
#   ./make-linux-x86_64.sh            # FPC resolved from PATH
#   FPC=/path/to/fpc ./make-linux-x86_64.sh
#   PCRE_SRC=/abs/path/to/pcre ./make-linux-x86_64.sh
#
# Extra FPC switches can be appended, e.g.:
#   ./make-linux-x86_64.sh -dCalcOpt
# ============================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# --- Resolve the Free Pascal driver ------------------------------
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
FPC_BINDIR="$(dirname "$FPC_BIN")"
export PATH="$FPC_BINDIR:$PATH"

# --- Build bundled PCRE (8-bit) for Linux ------------------------
PCRE_SRC="${PCRE_SRC:-$(cd "$HERE/../../3rd/pcre-8" 2>/dev/null && pwd)}"
PCRE_FLAGS=""
if [ -n "$PCRE_SRC" ] && [ -f "$PCRE_SRC/pcre_compile.c" ]; then
    PCRE_LIB="$PCRE_SRC/linux-lib"
    mkdir -p "$PCRE_LIB"
    if command -v gcc >/dev/null 2>&1; then
        echo "Building PCRE 8 from $PCRE_SRC"
        for f in pcre_byte_order pcre_chartables pcre_compile pcre_config \
                 pcre_default_tables pcre_dfa_exec pcre_exec pcre_fullinfo \
                 pcre_get pcre_globals pcre_maketables pcre_newline \
                 pcre_refcount pcre_study pcre_tables pcre_ucd \
                 pcre_valid_utf8 pcre_version pcre_xclass pcre_string_utils; do
            if [ ! -f "$PCRE_LIB/$f.o" ] || [ "$PCRE_SRC/$f.c" -nt "$PCRE_LIB/$f.o" ]; then
                gcc -c -O2 -fPIC -DHAVE_CONFIG_H -DSUPPORT_PCRE8 \
                    -I"$PCRE_SRC" "$PCRE_SRC/$f.c" -o "$PCRE_LIB/$f.o"
            fi
        done
        rm -f "$PCRE_LIB/libpcre.a"
        ar rcs "$PCRE_LIB/libpcre.a" "$PCRE_LIB"/*.o
        PCRE_FLAGS="-dRegex -Fl$PCRE_LIB -k-lc"
        echo "Regex enabled (PCRE 8)."
    else
        echo "gcc not found - building WITHOUT regex." >&2
    fi
else
    echo "PCRE C source not found - building WITHOUT regex." >&2
fi

# --- Build funcmd ------------------------------------------------
echo "Building funcmd with $FPC_BIN"
# shellcheck disable=SC2086
"$FPC_BIN" funcmd.dpr -B -Sd -O2 -Xs -Tlinux -dLinux $PCRE_FLAGS "$@"
