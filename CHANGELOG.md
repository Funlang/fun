# Changelog

This project records notable changes in the style of [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and follows [Semantic Versioning](https://semver.org/).

**English** (this file) · [简体中文](CHANGELOG.zh.md)

## [Unreleased]

- First open-source release of the Fun core and standard library source.
- The command-line `funcmd` now writes diagnostics to stderr and exits non-zero
  (1) on a parse or runtime error, so `a.fun && b.fun`, CI jobs and cron alarms
  no longer mistake a failed script for success. Runtime errors are prefixed
  with `file:line:`. A function traceback (one `  in name() (file:line)` line per
  frame, innermost first, capped at 10) is appended only in builds that define
  `-dFunTraceback`; the default build reports the failing command alone, so it
  pays nothing per call. Normal script output (`?.`) stays on stdout. The
  embedded `fun.dll` `Run` return-code contract is unchanged, and
  `-gui`/non-console runs stay silent as before. Diagnostics go through the OS
  standard-error handle (not the RTL `StdErr`/`ErrOutput` text file, which
  Delphi 7 does not declare), so the driver builds unchanged on Delphi 7 and
  Free Pascal.
- Added `README.md`, `CONTRIBUTING.md`, `.gitignore`, `.gitattributes`.
- Hardened string/list indexing and byte access against out-of-bounds memory
  access: out-of-range writes now raise, out-of-range reads yield a safe default
  (`s[i]`, `.toByte`, `.fromByte`, `.toNum(ptr:)`, `.movs`, `.x`, `.toStr`,
  list `@count`). String assignment keeps its reference semantics.
- Language version: 9.0.
- Bound JSON/FD nesting depth when parsing. The scanners are iterative, but the
  resulting tree is released, cloned and serialized recursively, so an
  attacker-supplied document with thousands of `[`/`{` levels could overflow the
  stack and crash the process (DoS). Nesting deeper than 512 levels now raises
  instead of building an unusable tree.
- Fix multi-row `DObject.Get`: the nested `Read` helper shadowed the `args`
  member, so fetching more than one row raised `@Fields not found`. The row loop
  now reads `this.args`.
- Added console input builtins in `libase.pas`: `'line'.input([prompt])`,
  `'char'.input([prompt])` (a single keypress in raw mode on a terminal) and
  `'all'.input([prompt])`. An optional second argument receives an `ok` flag
  that reports end of input; because Fun treats `''` and nil as equal, that flag
  is the only reliable way to stop a read loop that may see blank lines. Linux
  reads standard input byte by byte and supports all three modes; on Windows
  the builtin only reads lines, through the RTL `ReadLn`, so the text comes
  back in the build's string encoding (ANSI, or Unicode on Delphi 2009) and a
  multi-byte character is never split into bytes.
- Added strict comparison and a type id for basic values: `a.eq(b)` is true only
  when the type and the value both match (`nil`/`0`/`''`/`false` are distinct,
  `'1' <> 1`, `1 <> 1.0`, string compare is case-sensitive), and `a.type()`
  returns a portable logical type id. The ids are anchored to COM `VARENUM`
  (`VT_*`, the table behind Delphi's `VType` and ADO's `DataTypeEnum`) and
  normalize the runtime's platform-dependent tags: every integer width -> 3,
  every float width -> 5, every string form -> 8. Both live in `libase`, apply
  to basic (non-object) values, and leave the loose `=` unchanged; `100+` is
  reserved for Fun-only object kinds.

## [9.0] - 2026

- Data-centric scripting: built-in JSON and FD data formats, native list / set / tree collections, bundled PCRE regex.
- Interpreter core (value model / objects / control flow), built-in runtime library, and 58 standard-library modules.
- Dual build: command-line `funcmd` and embeddable runtime `fun.dll`.
- Delphi 2006/2009 and Free Pascal cross-platform builds (Windows / Linux / ARM / WinCE).
- Companion IDE (`funide`) and example applications (`notepad--`, `odbc-search`, benchmarks).
- Runtime C compilation (TCC), JIT, and inline assembly via the standard library.

> Note: this repository has a long pre-release history (back to 2010) that was not carried over into the open-source commits, so the changelog begins at the first open-source release.
