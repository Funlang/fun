fun q(lbl, s)
  try
    var n = s.getJson(json: 2);
    ?. lbl + ' OK ' + n.@toJson();
  except
    ?. lbl + ' ERR ' + @;
  end try;
end fun;
q('a [true] ', '[true]');
q('b [false]', '[false]');
q('c [1]    ', '[1]');
q('d [null] ', '[null]');
q('e [true,false]', '[true,false]');
q('f {a:true}', '{"a":true}');
