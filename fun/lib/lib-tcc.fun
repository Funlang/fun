// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

var tccdll = 'libtcc.dll';
var tcc = nil;
var tcc_error = nil;
try
  fun error(p, m)
    ?. m;
  end fun;
  tcc_error = error.@toCallback(nil, 'is:C');

  tcc = [
    New:     tccdll.getapi('tcc_new',            'v:i' ),
    Delete:  tccdll.getapi('tcc_delete',         'i:v' ),
    Error:   tccdll.getapi('tcc_set_error_func', 'iic:v'),
    Options: tccdll.getapi('tcc_set_options',    'is:i'),
    Compile: tccdll.getapi('tcc_compile_string', 'is:i'),
    Reloc:   tccdll.getapi('tcc_relocate',       'ii:i'), // 1
    Get:     tccdll.getapi('tcc_get_symbol',     'is:i'),
  ];
except ?. @;
end try;

fun ccompile(code, flag, name)
  fun GetArgs(m)
    if flag = nil then
      flag = m.@(1);
    end if;
    result = '';
  end fun;

  result = nil;
  code = code.replace(/^#!c\b(?:[:=]?\s*+(\w*+:\w*+))?/i, m->GetArgs(m));
  name = name or code.match(/\w++(?=\s*+\()/).@@();
  code = 'void _start(){}' & code;

  var ts = tcc.New();             //?, 'ts';    ?. ts;
  tcc.Error(ts, 0, tcc_error); // cdecl
  tcc.Options(ts, "-nostdlib -nostdinc -O2");
  var i  = tcc.Compile(ts, code); //?, 'comp';  ?. i;
  exit when i = -1;

  i = tcc.Reloc(ts, 1);           //?, 'reloc'; ?. i;
  exit when i = -1;

  var ptr = tcc.Get(ts, name);    //?, 'get';   ?. ptr;
  result = nil.getapi(ptr, flag);

  //tcc.Delete(ts);
  result = new [call: result, del: -> tcc.Delete(ts)];
  result.Run    = result.call;
  result.Delete = result.del;
end fun;
