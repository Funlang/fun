fun q(lbl, s)
  try
    var n = s.getJson(json: true, fd: true);
    ?. lbl + ' => ' + n.@toJson();
  except
    ?. lbl + ' => ERR ' + @;
  end try;
end fun;
q('a', '  x'.escape());
q('b', 'name zhang\nage 20'.escape());
q('c', 'a: 1\nb: 2'.escape());
q('d', '  \n   deep'.escape());
q('e', '``xZZ'.escape());
