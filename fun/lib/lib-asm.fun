// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-utils.fun';

// Executable-memory backend, resolved once at load. Windows keeps
// VirtualAlloc / VirtualFree. Linux uses libc mmap / munmap, and because the
// host ABI there is System V AMD64, any hand-written `#!asm` body for Linux
// must use the register-argument convention (rdi, rsi, ...), not the Win32
// stack form. See art/notes/library-port-plan.md.
var _asm_linux = 'host'.arg().getJson(fd: true).os = 'linux';
var _asm_alloc = nil;
var _asm_free  = nil;
if _asm_linux then
  _asm_alloc = 'libc.so.6'.getapi('mmap',   'piiiii:p');
  _asm_free  = 'libc.so.6'.getapi('munmap', 'pi:i');
else
  _asm_alloc = 'kernel32'.getapi('VirtualAlloc', 'iiii:i');
  _asm_free  = 'kernel32'.getapi('VirtualFree',  'iii:i');
end if;

// 64-bit little-endian byte dump. lib-utils' int2hex is fixed at 4 bytes
// because Fun's `>>` is 32-bit; a 64-bit host address (a @toCallback libffi
// closure lives above 4GB) needs all 8, extracted with div/mod by 256, which
// keeps the value's int64 type.
fun int2hex64(int)
  result = '';
  var v = int;
  for i = 0 to 7 do
    var b = v mod 256;
    result &= Hexs[b >> 4] & Hexs[b bit and 0x0f];
    v = v div 256;
  end do;
  result = result.upper();
end fun;

#*
  args: xxx...:x
  code: assembly
#
var Assembly = AssemblyBase;
class AssemblyBase(args, code, names)
  var MEM_COMMIT             = 0x1000;
  var MEM_RELEASE            = 0x8000;
  var PAGE_EXECUTE_READWRITE = 0x40;

  var msize = 0;
  var ptr   = nil;
  var Run   = nil;
  var call  = -> Run();
  var del   = -> Delete();

  fun New(n)
    msize = n;
    if _asm_linux then
      // libc mmap(NULL, n, PROT_READ|WRITE|EXEC, MAP_PRIVATE|ANONYMOUS, -1, 0)
      result = _asm_alloc(nil, n, 7, 0x22, -1, 0);
    else
      result = _asm_alloc(nil, n, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    end if;
  end fun;

  fun Delete()
    if ptr <> nil then
      if _asm_linux then
        result = _asm_free(ptr, msize);
      else
        result = _asm_free(ptr, 0, MEM_RELEASE);
      end if;
    end if;
    ptr = nil;
    msize = 0;
  end fun;

  fun GetArgs(m)
    if args = nil then
      args = m.@(1);
    end if;
    result = '';
  end fun;

  fun Compile(c)
    result = c.replace(/^#!(?:hex|bin)\b(?:[:=]?\s*+(\w*+:\w*+))?/, m->GetArgs(m))
              .replace(/^\s*+(?:[\da-f]{8}\s)?(?:[^\da-f]++)?(([\da-f]++)(:(?2))?(\x20(?2))*+)\s[^\r\n]++/gim, '$1')
              .replace(/\W++/g, '');
  end fun;

  fun Load(c)
    if c = nil then
      c = code;
    end if;
    c = this.Compile(c); //?. c;
    if _asm_linux then
      // System V AMD64 passes arguments in registers and the caller cleans up,
      // so Win32's `ret n` tail is wrong here (it would corrupt rsp). Only make
      // sure the code ends in a plain return.
      if c !~ /C3$/i then
        c &= 'C3';
      end if;
    else
      if c !~ /C2....$/i then
        c &= 'C2%s00'.format( str2hex( (args.length()*4-8).toChar() ) ); // < 64
      end if;
    end if;

    var s = hex2str(c); //?. str2hex(s);
    Delete();
    ptr   = New(s.length()*charSize());
    s.move(ptr); // ansi only ! -> now unicode ok !

    Run   = nil.getapi(ptr, args);
    return this;
  end fun;
end class;
