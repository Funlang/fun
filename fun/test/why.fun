fun q(lbl, s)
  try
    var n = s.getJson(json: 0);
    ?. lbl + ' => ' + n.@toJson();
  except
    ?. lbl + ' => ERR ' + @;
  end try;
end fun;
q('A [10,23  ', '[10,23');
q('B [12,34  ', '[12,34');
q('C {"a":456', '{"a":456');
q('D [1,23   ', '[1,23');
q('E x: hello', 'x: hello');
q('F [12]    ', '[12]');
q('G [10,23] ', '[10,23]');
