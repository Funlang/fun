fun q(lbl, s, j, f)
  try
    var n = s.getJson(json: j, fd: f);
    ?. lbl + ' => ' + n.@toJson();
  except
    ?. lbl + ' => ERR ' + @;
  end try;
end fun;

?. '-- fd independence --';
q('fd-only(json0)', '  x'.escape(), 0, true);          // fd true, json 0 -> lenient FD
q('json2-fdfalse ', '  x'.escape(), 2, false);          // json2, fd false -> JSON strict
q('json1-fdtrue  ', '  x'.escape(), 1, true);           // fd true, json 1 -> lenient FD
q('json2-fdtrue  ', '  x'.escape(), 2, true);           // fd true, json 2 -> strict FD
?. '-- FD multi-error: first wins --';
q('fd-2err       ', '  a\n  b'.escape(), 2, true);
?. '-- fd valid lenient variants --';
q('fd-valid-j0   ', 'name zhang\nage 20'.escape(), 0, true);
q('fd-valid-j1   ', 'name zhang\nage 20'.escape(), 1, true);
?. '-- host arg still works --';
var h = 'host'.arg().getJson(fd: true);
?. 'host.os=' + h.os + ' bits=' + h.bits;
