@echo off
rem ============================================================
rem Fun build environment
rem ============================================================
rem Edit the paths below to point at your installed toolchains,
rem then run any of the make-*.bat scripts in this folder.
rem
rem You may also pre-set these variables in your shell/IDE before
rem running a build; the `if not defined` guards let your values win.
rem ============================================================

rem --- Free Pascal root (used by make-linux / arm-linux / win64 / wince) ---
if not defined FPC set FPC=D:\FPC\2.4.0

rem --- Delphi 2006 (used by make-2006.bat) ---
if not defined DELPHI2006 set DELPHI2006=D:\Borland\Delphi2006

rem --- Delphi 2009 (used by make-2009.bat) ---
if not defined DELPHI2009 set DELPHI2009=D:\Borland\Delphi2009
