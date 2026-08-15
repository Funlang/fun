// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-os.fun';

var PROCESS_QUERY_INFORMATION = 0x0400;
var PROCESS_VM_READ           = 0x0010;
var MEM_COMMIT     = 0x00001000;
var PAGE_READWRITE = 0x04;
var TH32CS_SNAPPROCESS = 0x2;
var MB = 1024 ^ 2;

var proc = Proclass();
class Proclass()
  var lib = 'kernel32';

  var proc = new [
      Info:     lib.getapi('GetSystemInfo',      's:v'),
      Open:     lib.getapi('OpenProcess',        'iii:i'),
      Query:    lib.getapi('VirtualQueryEx',     'iisi:i'),
      ReadMem:  lib.getapi('ReadProcessMemory',  'iipip:i'),
      Snapshot: lib.getapi('CreateToolhelp32Snapshot',  'ii:i'),
      First:    lib.getapi('Process32First',  'is:i'),
      Next:     lib.getapi('Process32Next',  'is:i')
  ];

  fun ProcList(fullPath, exeList, exeLike)
    result = new [];
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
  end fun;

  fun SearchMem(pid, re, size, all)
    if all then
      result = new [];
    end if;

    if size = nil then
      size = 64; // 64MB
    end if;
    size *= MB;

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
  end fun;
end class;
