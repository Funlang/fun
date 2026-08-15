// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-os.fun';

#*
  args: xxx...:x
  code: assembly
#
var Assembly = AssemblyBase;
class AssemblyBase(args, code, names)
  var MEM_COMMIT             = 0x1000;
  var MEM_RELEASE            = 0x8000;
  var PAGE_EXECUTE_READWRITE = 0x40;

  var alloc = 'kernel32'.getapi('VirtualAlloc', 'iiii:i');
  var free  = 'kernel32'.getapi('VirtualFree',  'iii:i');
  var ptr   = nil;
  var Run   = nil;
  var call  = -> Run();
  var del   = -> Delete();

  fun New(n)
    return alloc(nil, n, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  end fun;

  fun Delete()
    if ptr <> nil then
      result = free(ptr, 0, MEM_RELEASE);
    end if;
    ptr = nil;
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
    if c !~ /C2....$/i then
      c &= 'C2%s00'.format( str2hex( (args.length()*4-8).toChar() ) ); // < 64
    end if;

    var s = hex2str(c); //?. str2hex(s);
    Delete();
    ptr   = New(s.length()*charSize());
    s.move(ptr); // ansi only ! -> now unicode ok !

    Run   = nil.getapi(ptr, args);
    return this;
  end fun;
end class;
