#!/bin/sh
# ============================================================
# Regenerate src/core/version.inc from git metadata.
#
#   funVersion <- commit date of HEAD, YYYYMMDD (deterministic per commit)
#   funRelease <- preserved from the current file, or --release VER
#
# The commit date is used instead of a build timestamp so that rebuilding the
# same commit always yields the same binary (reproducible), while the number
# still advances with each new commit - which is exactly what a script wants
# when it probes whether the interpreter is new enough.
#
# Safe outside a git checkout (source tarball): if git is unavailable or the
# tree has no commits, the existing version.inc is left untouched.
#
# Usage:
#   sh src/prj/fun/gen-version.sh
#   sh src/prj/fun/gen-version.sh --release 9.1
# ============================================================
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="$ROOT/src/core/version.inc"

release=""
case "$1" in
    -r|--release) release="$2" ;;
    "") ;;
    *) echo "usage: $0 [--release X.Y]" >&2; exit 2 ;;
esac

# Preserve the curated release string unless overridden.
if [ -z "$release" ] && [ -f "$OUT" ]; then
    release="$(sed -n "s/^[[:space:]]*funRelease[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" "$OUT" | head -n 1)"
fi
[ -n "$release" ] || release="0.0"

ver=""
if command -v git >/dev/null 2>&1; then
    # cd rather than `git -C` (that flag needs git >= 1.8.5). --date=short
    # (YYYY-MM-DD) works on old git too; compact to YYYYMMDD.
    ver="$( cd "$ROOT" && git log -1 --format=%cd --date=short 2>/dev/null | tr -d '-' )" || true
fi
if [ -z "$ver" ]; then
    echo "gen-version: git unavailable; leaving $OUT unchanged" >&2
    exit 0
fi

cat > "$OUT" <<EOF
// AUTO-GENERATED - do not edit by hand.
// Regenerate with:  sh src/prj/fun/gen-version.sh
//
// funVersion: numeric build stamp, YYYYMMDD, derived from the git commit date
//   of HEAD (deterministic per commit: rebuilding the same commit any day gives
//   the same number, unlike the FPC {\$I %DATE%} build date). Scripts probe the
//   running interpreter with \`N.time()\` for N in 2010..2099, or with the
//   \`version\` field of 'host'.arg(); both read this constant.
// funRelease: curated language version string (see the "Version" line in the
//   README). The generator preserves it; pass --release X.Y to change it.
funVersion = $ver;
funRelease = '$release';
EOF

echo "gen-version: funVersion=$ver funRelease=$release -> $OUT"
