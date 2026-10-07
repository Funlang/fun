fun p(lbl, s, j, f)
  try
    var n = s.getJson(json: j, fd: f);
    ?. lbl + ' => ' + n.@toJson();
  except
    ?. lbl + ' => ERR ' + @;
  end try;
end fun;

fun runAll(tag, j, f)
  var a = ['{"a":1}',
           '{"a":[1,{"b":2}],"c":null}',
           '{"a":}',
           '{"a":"x',
           '{"a":1, "b":[1,2',
           '{"a":1]}}',
           '{"a": 12x34}',
           '{"a":1} !',
           '{a:1}',
           'name: zhang, age: 20',
           '0x1f',
           '0x1',
           '[1,2,3]',
           '  ',
           '',
           '[}',
           ']]}',
           ',1',
           '1,2',
           '{"deep":[[[[1]]]]}'];
  a.@each((v, i){ p(tag + '#' + i, v, j, f); });
end fun;

runAll('L0', false, false);
runAll('L1', true, false);
runAll('FD', false, true);
