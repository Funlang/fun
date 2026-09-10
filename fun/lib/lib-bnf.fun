// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-stack.fun';
use 'lib-utils.fun';
use ':bnf.fd' as bnf;
bnf = bnf.getJson(fd: true); //?. bnf.@toJson(fd: true);
var re_bnf = bnf.@regex.toRegex('gx'); # /\b(?P<Ref>[A-Z]\w++)\b/g;

//test();
fun test();
  var cb  = CBNF(bnf, dup: true);
  ?. cb.regex;
  ?. cb.regex = bnf.@regex;
end fun;

class CBNF(rls, name, dup, ws)
  var ns = new [];
  var names;
  var count = new [];
  var regex = expand(rls.@name or name);
  if dup then
    regex = '(?J)' & regex;
  end if;
  fun expand(name)
    result = rls[name].replace(re_bnf, (m){
      if m.@('Ref') <> nil then
        var n = m.@('Ref');
        var nn = n;
        if not dup and count[n] > 0 then
          nn &= '_' & count[n];
        end if;
        count[n] += 1;
        ns[nn] = 1;
        if rls[n] = nil then
          ?. 'EBNF: $n not found'.eval();
        end if;
        result = '(?<$nn>%s)'.eval().format(count[n]>1 and '(?&$n)'.eval() or expand(n));
        if ws then
          result = '\s*+$result\s*+'.eval();
        end if;
      else
        result = m.@@();
      end if;
    });
  end fun;

  fun group(m, actions)
    if names = nil then
      names = new [];
      for k: v in ns do next when k !~ /^[A-Z]/;
        var i = m.@(k, 1);
        if i > 0 then
          names [k] = i;
          names.[i] = k;
        end if;
      end do; //?. names.@toJson();
    end if;

    result = Stack();
    var g = m.@@('*');
    for i = 0 to m.gcount() - 1 do                   // 已按 匹配  排序
      var os = str2int(g, i * 8    , packed: 2) - 1; // 无需 start 变量
      var oe = str2int(g, i * 8 + 4, packed: 2) - 1;
      if names.[i] <> nil and os >= 0 then
        var o = new [t: m.@(i), n: names.[i].replace(/_\d++$/, ''), e: oe];
        reduce(result, o);
      end if;
    end do;
    reduce(result);

    fun reduce(s, o)
      result = s;
      loop
        var p = result.peek();
        exit when p = nil or not p.@a or o <> nil and o.e <= p.e;
        result.pop();
      end loop;
      if o = nil then
        go(result.list);
        fun go(list, p)
          for n in list do next when n = nil;
            go(n.@, n);
            var action = actions?.[n.n];
            action?(n, m: m, p: p, r: s);
          end do;
        end fun;
      else
        var p = result.peek();
        if p <> nil and o.e <= p.e then
          p.@ = p.@ or new [];
          p.@.@add(o);
          o.@a = 1;
        end if;
        result.push(o);
      end if;
    end fun;
  end fun;

  fun parse(s, actions)
    var ret = new [];
    s.match(regex.toRegex('gxm'), (m){
      var g = group(m, actions);
      if g.done then
        ret = g.done;
        g.done = nil;
      else
        ret.@add(g.ret or g.list);
        g.ret  = nil;
      end if;
    });
    result = ret;
  end fun;
end class;
