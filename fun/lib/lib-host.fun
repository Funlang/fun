// Copyright (c) 2010-2026 Zhang WeiDong <zwd@funlang.org>
// SPDX-License-Identifier: MIT
//
// lib-host: portable host services (path / env / process).
//
// Why a separate module instead of lib-os: lib-os resolves ~40 Windows
// handles unconditionally at load time, so it cannot even be loaded on Linux.
// Anything that only needs a couple of host services should depend on this
// module instead, so it stays loadable on every host.
//
// Platform dispatch follows the three rules validated in
// fun/test/lib-os-dispatch-prototype.fun (see art/notes/library-port-plan.md):
//   1. detect the host once, at load time, from 'host'.arg();
//   2. resolve native handles only on the host that owns them;
//   3. keep one public name/signature and put the host branch inside.
//
// Names are Host*-prefixed on purpose: lib-os already exports GetCurrPath /
// GetTempPath / GetFullPath, and two modules exporting the same name would
// shadow each other in Fun's UID chain.
//
// Linux note: an OUT buffer must be passed as the Fun string's real address
// (buf.toNum(-1)), not as an 's'/'p' string argument - the engine would hand C
// a pointer to a temporary copy and the writes would be lost.

var _hostFacts  = 'host'.arg().getJson(fd: true);
var _hostOs     = _hostFacts.os;
var _isWindows  = _hostOs = 'windows';
var _isLinux    = _hostOs = 'linux';
var _hostSep    = '/';

fun IsWindows()
  result = _isWindows;
end fun;

fun IsLinux()
  result = _isLinux;
end fun;

// Path separator of the running host.
fun HostSep()
  result = _hostSep;
end fun;

//--------------------------------------------------------------
// native handles, resolved per host
//--------------------------------------------------------------
var _HOST_MAX_PATH = 260;

var _hostGetCurrPath;   // Windows: kernel32.GetCurrentDirectory
var _hostGetTempPath;   // Windows: kernel32.GetTempPath
var _hostGetFullPath;   // Windows: kernel32.GetFullPathName
var _hostGetCmdLine;    // Windows: kernel32.GetCommandLine
var _hostGetCwd;        // Linux: libc.getcwd
var _hostGetenv;        // Linux: libc.getenv
var _hostStrlen;        // Linux: libc.strlen

if _isLinux then
  _hostGetCwd  = 'libc.so.6'.getapi('getcwd',  'pi:p');
  _hostGetenv  = 'libc.so.6'.getapi('getenv',  's:p');
  _hostStrlen  = 'libc.so.6'.getapi('strlen',  'p:i');
else
  _hostSep = '\';
  _hostGetCmdLine  = 'kernel32'.getapi('GetCommandLine',       ':s');
  _hostGetCurrPath = 'kernel32'.getapi('GetCurrentDirectory', 'ip:i');
  _hostGetTempPath = 'kernel32'.getapi('GetTempPath',         'ip:i');
  _hostGetFullPath = 'kernel32'.getapi('GetFullPathName',     'sipp:i');
end if;

//--------------------------------------------------------------
// command line
//
// Windows returns the raw process command line. Linux has no such string, so
// it is rebuilt from argv and quoted the Windows way (wrap in double quotes,
// double any inner quote) - that way the existing lib-param/lib-cmdline
// tokenizer keeps working unchanged on both hosts.
//--------------------------------------------------------------
fun HostCommandLine()
  if _isLinux then
    result = '';
    var i = 0;
    while i.arg() <> '' do
      var a = i.arg();
      var dq = 34.toChar();
      if a.subpos(' ') >= 0 or a.subpos(dq) >= 0 then
        a = '"' & a.replace(dq, dq & dq) & '"';
      end if;
      if result <> '' then result &= ' '; end if;
      result &= a;
      i += 1;
    end do;
  else
    result = _hostGetCmdLine();
  end if;
end fun;

//--------------------------------------------------------------
// current directory
//--------------------------------------------------------------
fun HostCurrPath()
  if _isLinux then
    var buf = ' '.x(4097);
    var p = _hostGetCwd(buf.toNum(-1), 4096);
    if p = nil then
      result = '';
    else
      result = buf.substr(len: _hostStrlen(buf.toNum(-1)));
    end if;
  else
    result = ' '.x(_HOST_MAX_PATH + 1);
    var ln = _hostGetCurrPath(_HOST_MAX_PATH, result);
    result = result.substr(len: ln);
  end if;
end fun;

//--------------------------------------------------------------
// temp directory, with a trailing separator, then 'extra' appended
// (same contract as lib-os.GetTempPath)
//--------------------------------------------------------------
fun HostTempPath(extra)
  if _isLinux then
    var t = _hostGetenv('TMPDIR');
    if t = nil then
      result = '/tmp/';
    else
      var ln  = _hostStrlen(t);
      var buf = ' '.x(ln + 1);
      t.move(buf.toNum(-1), ln);
      result = buf.substr(len: ln).replace(%[/]++$%, '') & '/';
    end if;
    result &= extra;
  else
    result = ' '.x(_HOST_MAX_PATH + 1);
    var ln = _hostGetTempPath(_HOST_MAX_PATH, result);
    result = result.substr(len: ln) & extra;
  end if;
end fun;

//--------------------------------------------------------------
// absolute path. Unlike libc realpath() this is purely lexical, so it also
// works for paths that do not exist yet (matching GetFullPathName's contract).
//--------------------------------------------------------------
fun HostFullPath(f)
  if _isLinux then
    var s = f;
    if s = '' then
      result = HostCurrPath();
      return;
    end if;
    if s.substr(0, 1) <> '/' then
      s = HostCurrPath() & '/' & s;
    end if;
    // segment scan, no regex dependency: collapse '' / '.' and resolve '..'
    var kept = new [];
    var cur  = '';
    var i    = 0;
    while i <= s.length() do
      var ch = s.substr(i, 1);
      if ch = '/' or i = s.length() then
        if cur = '..' then
          if kept.@count() > 0 then kept.@count(-1); end if;
        elsif cur <> '' and cur <> '.' then
          kept.@add(cur);
        end if;
        cur = '';
      else
        cur &= ch;
      end if;
      i += 1;
    end do;
    result = '';
    for p in kept do
      result = result & '/' & p;
    end do;
    if result = '' then result = '/'; end if;
  else
    result = ' '.x(_HOST_MAX_PATH + 1);
    var r = '';
    var ln = _hostGetFullPath(f, _HOST_MAX_PATH, result, r);
    result = result.substr(len: ln);
  end if;
end fun;
