// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-asm.fun';
use 'lib-zlib.fun';
//use 'lib-sse-compress.fun';

var asms = AsmsInit();
fun AsmsInit()
  var all;
  var sse = false;
  if zlib then //?. 'gz';
    #* use ':asm-list.fd.gz' as gz;
    all = inflate(gz); #
    use ':asm-list.fd.2.gz' as gz;
    //?, gz.length(); ?, str2hex(gz.substr(len:4)); ?, str2hex(gz.substr(-4));
    all = inflate(gz); //?. all.length();
    //all = SseDecompress(all);
    sse = true;
  else         //?. 'fd';
    // No zlib (Linux, until lib-zlib is ported): use the uncompressed list
    // that ships beside this module. `use` is compile-time, so both blobs
    // are embedded on every host; the Windows branch never reaches here
    // because zlib.dll loads there.
    use ':asm-list.fd' as fd;
    all = fd; #
  end if;
  result = all.getJson(fd: true, sse: sse); //?, 'asms'; ?. result.@count();
end fun;

Assembly = AssemblyPro;
class AssemblyPro = AssemblyBase()
  fun Compile(c)
    if c =~ /^#!asm\b/ then
      c = c.replace(/^#!asm\b(?:[:=]?\s*+(\w*+:\w*+))?/, m->GetArgs(m))
           .replace(/^\s*+([@\w][^;\r\n]+[^;\s])?\s*(;.*)?$/gm, (m){
        var a = m.@(1).replace(/\s++(?=[>)\]+*:,])|(?<=[<(\[+*:-])\s++/g, '')
                      .replace(/,\s++/g, ',')
                      .replace(/(?<=\s)\s++|\s++$/g, ''); //?. a;
        exit when a = nil;
        var asm = a;
        if asms[a] = nil then
          // function names in fun
          asm = asm.replace(/<(\w++)>/g, (n){
            var fn = names[n.@(1)];
            if fn <> nil then
              try      //[fun1: [fn: fn1, type: 'i:i', object: this], ...]
                result = int2hex(fn.fn.@toCallback(fn.object, fn.type, true));
              except   //[fun1:  fn1.@toCallback(this, 'i:i', true) , ...]
                result = int2hex(fn);
              end try;
            else
              raise '%s not found.'.format(n.@(1));
            end if;
          });
          // numbers
          a = asm.replace(/[-+]?(?<!\*)\$?\b([\dA-F]++\b)/g, (n){
            var j = n.@(1).length();
            result = '%$j'.eval();
          });
        end if;
        if asms[a] = nil then
          raise '$a not found.'.eval();
        else
          result = asms[a];
          // numbers
          if result =~ /%/ then
            var r = result;
            asm.replace(/[-+]?(?<!\*)(\$)?\b([\dA-F]++\b)/g, (n){
              r = r.replace(/%(\d)/, (o){
                var h = n.@(2);
                if n.@(1) = '$' then
                  if h.length() = 8 then
                    h = h.substr(6, 2) & h.substr(4, 2) & h.substr(2, 2) & h.substr(0, 2);
                  elsif h.length() = 4 then
                    h = h.substr(2, 2) & h.substr(0, 2);
                  end if;
                end if;
                if n.@@() =~ /^-/ then
                  // todo
                  if h.length() = 2 then h = h div 1; //?. h;
                    h = h bit xor 0xff + 1;           //?. h;
                    h = byte2hex(h);                  //?. h;
                  end if;
                end if;
                result = h;
              });
            });
            result = r;
          end if;
        end if;
      }).replace(/\W++/g, '');
      return c;
    else
      return base.Compile(c);
    end if;
  end fun;
end class;
