// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

// lib-proc: process listing (and, on Windows, memory scanning).
//
// lib-os is deliberately NOT `use`d at module scope: it resolves ~40 Windows
// handles eagerly and would make this module unloadable on Linux. The Windows
// branches pull it in lazily instead (a function-scope `use` runs only when the
// branch is reached), so Linux never touches it. The Linux backend reads /proc
// through libc.

var PROCESS_QUERY_INFORMATION = 0x0400;
var PROCESS_VM_READ           = 0x0010;
var MEM_COMMIT     = 0x00001000;
var PAGE_READWRITE = 0x04;
var TH32CS_SNAPPROCESS = 0x2;
var MB = 1024 ^ 2;

var _osLinux = 'host'.arg().getJson(fd: true).os = 'linux';

//--------------------------------------------------------------
// Linux backend (libc + /proc). Resolved only on Linux.
//--------------------------------------------------------------
var _dirOpen;
var _dirRead;
var _dirClose;
var _cSize;
var _cCopy;
var _readlink;
var _open;
var _pread;
var _close;
var _strtoull;
if _osLinux then
  var L = 'libc.so.6';
  _dirOpen  = L.getapi('opendir',  's:p');
  _dirRead  = L.getapi('readdir',  'p:p');
  _dirClose = L.getapi('closedir', 'p:i');
  _cSize    = L.getapi('strlen',   'p:i');
  _cCopy    = L.getapi('strcpy',   'pp:i');
  _readlink = L.getapi('readlink', 'spi:i');
  _open     = L.getapi('open',     'sii:i');
  _pread    = L.getapi('pread',    'ipil:l');
  _close    = L.getapi('close',    'i:i');
  _strtoull = L.getapi('strtoull', 'sii:l');
end if;

var _D_NAME = 19; // struct dirent.d_name offset on 64-bit Linux

// NUL-terminated C string at address p
fun _cStr(p)
  var n = _cSize(p);
  var b = ' '.x(n + 1);
  _cCopy(b.toNum(-1), p);
  result = b.substr(0, n);
end fun;

fun _readFile(path, cap)
  result = '';
  var fd = _open(path, 0, 0);
  if fd >= 0 then
    var b = ' '.x(cap + 1);
    var n = _pread(fd, b.toNum(-1), cap, 0);
    _close(fd);
    if n > 0 then result = b.substr(0, n); end if;
  end if;
end fun;

fun _readLinkStr(path)
  var b = ' '.x(4097);
  var n = _readlink(path, b.toNum(-1), 4096);
  if n > 0 then result = b.substr(0, n); else result = ''; end if;
end fun;

fun _procName(pid)
  result = _readFile('/proc/' & pid & '/comm', 256).replace(/[\r\n]/, '');
end fun;

var proc = Proclass();
class Proclass()
  var lib = 'kernel32';

  var proc = nil;
  if not _osLinux then
    proc = new [
      Info:     lib.getapi('GetSystemInfo',      's:v'),
      Open:     lib.getapi('OpenProcess',        'iii:i'),
      Query:    lib.getapi('VirtualQueryEx',     'iisi:i'),
      ReadMem:  lib.getapi('ReadProcessMemory',  'iipip:i'),
      Snapshot: lib.getapi('CreateToolhelp32Snapshot',  'ii:i'),
      First:    lib.getapi('Process32First',  'is:i'),
      Next:     lib.getapi('Process32Next',  'is:i')
    ];
  end if;

  fun ProcList(fullPath, exeList, exeLike)
    result = new [];
    if _osLinux then
      var d = _dirOpen('/proc');
      if d <> nil and d <> 0 then
        loop
          var e = _dirRead(d);
          exit when e = nil or e = 0;
          var name = _cStr(e + _D_NAME);
          if name =~ /^\d+$/ then
            var pid = name.toNum();
            var exe = _procName(pid);
            if (exeList = nil or exe in exeList) and (exeLike = nil or exe =~ exeLike) then
              if fullPath then
                var s = _readLinkStr('/proc/' & pid & '/exe');
                if s <> '' then exe = s; end if;
              end if;
              result.@add(new [pid: pid, exe: exe]);
            end if;
          end if;
        end loop;
        _dirClose(d);
      end if;
    else
      use 'lib-os.fun';
      var h = proc.Snapshot(TH32CS_SNAPPROCESS, 0);
      var i = 8 * 4 + MAX_PATH;
      var pe = int2str(i + 4) & 0.x(i);
      if proc.First(h, pe) then
        loop
          var pid = str2int(pe.substr(8, 4));
          var exe = pe.substr(9 * 4).replace(/\x00.*$/, '');
          if (exeList = nil or exe in exeList) and (exeLike = nil or exe =~ exeLike) then
            if fullPath then
              var s = GetProcName(pid);
              if s <> '' then
                exe = s;
              end if;
            end if;
            result.@add(new [pid: pid, exe: exe]);
          end if;
          exit when not proc.Next(h, pe);
        end loop;
      end if;
      close(h);
    end if;
  end fun;

  fun SearchMem(pid, re, size, all)
    if all then
      result = new [];
    end if;

    if size = nil then
      size = 64; // 64MB
    end if;
    size *= MB;

    if _osLinux then
      // Best-effort /proc scan. Regions come from /proc/<pid>/maps, data from
      // /proc/<pid>/mem. Addresses are parsed with libc strtoull (Fun has no
      // 64-bit literals/arithmetic); they are only ever carried as values.
      var maps = _readFile('/proc/' & pid & '/maps', 1024 * 1024);
      if maps = '' then exit; end if;
      var fd = _open('/proc/' & pid & '/mem', 0, 0);
      if fd < 0 then exit; end if;
      use 'lib-regex.fun'; // only the Linux path needs line splitting
      var chunk = 64 * 1024;
      var buf = ' '.x(chunk);
      var prev = '';
      for ln in split(/\n/, maps) do
        var m = ln.match(/^([0-9a-f]++)-([0-9a-f]++)\s([rwx-]++)/);
        if m and m.@(3).subpos('w') >= 0 then
          var a = _strtoull(m.@(1), 0, 16);
          var b = _strtoull(m.@(2), 0, 16);
          var cur = a;
          while cur < b do
            var n = b - cur;
            if n > chunk then
              n = chunk;
            end if;
            var got = _pread(fd, buf.toNum(-1), n, cur);
            if got <= 0 then
              exit;
            end if;
            var s = prev & buf.substr(0, got);
            var mm = s.match(re);
            if mm then
              if all then
                result.@add(mm.@@());
              else
                _close(fd);
                return mm;
              end if;
            end if;
            prev = s.substr(-1024);
            cur += got;
          end do;
        end if;
      end do;
      _close(fd);
    else
      use 'lib-os.fun';
      var r = 0.x(36);
      proc.Info(r);
      var min = str2int(r.substr( 8, 4)); //?. min;
      var cur = min;
      var max = str2int(r.substr(12, 4)); //?. max;

      var h = proc.Open(PROCESS_VM_READ bit or PROCESS_QUERY_INFORMATION, false, pid);
      if h <> 0 then
        try
          var prev = '';
          while cur < max do
            if proc.Query(h, cur, r, 28) then
              var siz = str2int(r.substr(12, 4)); //?. siz;
              if str2int(r.substr(16, 4)) = MEM_COMMIT and str2int(r.substr(20, 4)) = PAGE_READWRITE then
                cur = str2int(r.substr(0, 4));
                var p = cur; //?, p; ?. siz;
                var s = 0.x(siz);
                if proc.ReadMem(h, p, s, siz, 0) then //?. s;
                  var m = (prev.substr(-1024) & s).match(re);
                  if m then
                    if all then
                      result.@add(m.@@());
                    else
                      return m;
                    end if;
                  end if;
                  prev = s;
                else
                  prev = '';
                  //?. ShowLastError();
                  //exit;
                end if;
              else
                prev = '';
              end if;
              cur += siz;
            else //?. 'Error';
              exit;
            end if;
          end do;
        finally
          close(h);
        end try;
      end if;
    end if;
  end fun;
end class;
