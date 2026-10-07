fun pj(label, s)
  try
    var n = s.getJson(json: 2);
    ?. label + ' => OK ' + n.@toJson();
  except
    ?. label + ' => ERR ' + @;
  end try;
end fun;

fun pf(label, s)
  try
    var n = s.getJson(json: 2, fd: true);
    ?. label + ' => OK ' + n.@toJson();
  except
    ?. label + ' => ERR ' + @;
  end try;
end fun;

fun pl(label, s)   // lenient json:true
  try
    var n = s.getJson(json: true);
    ?. label + ' => OK ' + n.@toJson();
  except
    ?. label + ' => ERR ' + @;
  end try;
end fun;

?. '== strict JSON ==';
pj('valid1     ', '{"a":1}');
pj('valid2     ', '{"a":[1,{"b":2}],"c":null}');
pj('c1 missval ', '{"a":}');
pj('c2 untermS ', '{"a":"x');
pj('c3 unclosed', '{"a":1, "b":[1,2');
pj('c4 extraCl ', '{"a":1]}}');
pj('c5 badnum  ', '{"a": 12x34}');
pj('c6 badchar ', '{"a":1} !');
pj('c7 bareword', '{a:1}');
pj('c8 tailkv  ', 'name: zhang, age: 20');
pj('c9 untermin', '{"a":1} 2');
pj('x1 leadbrk ', ']}');
pj('x2 hex     ', '0x1f');
pj('x3 hexdig  ', '0xff');
pj('x4 hex1    ', '0x1');
pj('x5 cross   ', '[}');
pj('x6 empty   ', '');
pj('x7 space   ', '   ');
pj('x8 commalead', ',1');
?. '== lenient json:true (must all stay OK-like) ==';
pl('l1 missval ', '{"a":}');
pl('l2 hex     ', '0x1f');
pl('l3 leadbrk ', ']}');
pl('l4 valid   ', '{"a":1}');
?. '== FD ==';
pf('fd ok      ', 'name:zhang\nage:20');
pf('fd badind  ', '  x');
pf('fd ok2     ', 'a: 1\nb: 2');
