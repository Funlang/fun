// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-bnf.fun';
use ':fd.bnf.fd' as rules;
rules = rules.getJson(fd: true); //?. rules.@toJson(fd: true);

fun parse(s)
  root = new [];
  stak = Stack();
  stak.push([ind: -1, node: root]);
  result = cbcb.parse(s, actions);
end fun;

var root;
var stak;
var cbcb = CBNF(rules, dup: 0); //?. cb.regex.replace(/\x20/g, '');
var actions = [
      Comment: (o,r) {
        var rt = getRet(r);
        rt.comment = o.t;
      },
      Key: (o,r) {
        var rt = getRet(r);
        rt.key = o.val or o.t;
        while stak.peek().ind >= rt.ind do
         stak.pop();
        end do;
        var pp = stak.peek().node;
        if rt.key = '-' then
          var nd = new [];
          pp.@add(nd);
          rt.node = nd;
        else
          var nd = new [];
          pp[rt.key] = nd;
          rt.node = nd;
        end if;
        stak.push(rt);
        r.done = root;
      },
      Val: (o,r,p) {
        if p?.n? <> 'Unqkey' then
          var rt = getRet(r);
          rt.val = o.val;
          stak.pop();
          if rt.key = '-' then
            stak.peek().node[-1] = rt.val;
          else
            stak.peek().node[rt.key] = rt.val;
          end if;
        end if;
      },
      Ind: (o,r) {
        if o.@ then
          o.val = o.t.replace(/\t/g, '  ').length() div 2;
          o.@ = nil;
        end if;
        var rt = getRet(r);
        rt.ind = o.val;
      },
      Indx: (o,p) {
        if o.t =~ /^\d++/ then
          p.val = o.t.match(/^\d++/).@@() * 1;
        else
          p.val = o.t.length();
        end if;
        p.@ = nil;
      },
      Length: (o,m,p) {
        p.val = m.@(o.t.toNum(), 2);
        p.@ = nil;
      },
      Qstring: (o,p) {
        p.val = unq(o.t);
        p.@ = nil;
      },
      Number: (o,p) {
        p.val = o.t.toNum();
        p.@ = nil;
      },
      Const: (o,p) {
        p.val = [
                  'true' : true,
                  'false': false,
                  'null' : null,
                  '[]'   : [],
                  '{}'   : '{}'.getJson(),
                ][o.t];
        p.@ = nil;
      },
      Unqkey: (p) {p.val = p.t; p.@ = nil},
      Unqstr: (p) {p.val = p.t; p.@ = nil},
    ];

fun getRet(r)     # *
  r.ret = r.ret or new [];
  result = r.ret; # result = [];
end fun;

fun unq(s)
  var esc = false;
  if s =~ /^\\/ then
    esc = true;
    s = s.substr(1);
  end if;
  var c = s.substr(0, 1);
  s = s.substr(1, -2).replace(c.x(2), c);
  if esc then
    s = s.escape();
  end if;
  result = s;
end fun;
