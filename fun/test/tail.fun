fun q(lbl, s, j, f)
  try
    var n = s.getJson(json: j, fd: f);
    ?. lbl + ' => ' + n.@toJson();
  except
    ?. lbl + ' => ERR ' + @;
  end try;
end fun;
?. '-- JSON-flat dialect (fd:false) --';
q('t1 json0  ', 'name: zhang, age: 20', 0, false);
q('t2 json1  ', 'name: zhang, age: 20', 1, false);
q('t3 json2  ', 'name: zhang, age: 20', 2, false);
q('t4 json0  ', 'a: 1, b: 2', 0, false);
q('t5 json0  ', '[1,2,3', 0, false);
q('t6 json0  ', '{"a":1} 2', 0, false);
q('t7 json0  ', 'x: 9', 0, false);
?. '-- FD (fd:true) --';
q('f1 fd     ', 'a 1\nb 2', 0, true);
q('f2 fd     ', 'a 1\nb', 0, true);          // trailing key, no value
q('f3 fd     ', 'a\n b 1', 0, true);
q('f4 fd     ', 'a\n b', 0, true);            // trailing nested key, no value
