// Strict mode (json:2) acceptance table. Run:  src/prj/fun/funcmd fun/test/strict-valid.fun
// Every line must print PASS. Scalar roots (20, "hi", true, null) are legal
// JSON; numbers stay lenient (.5, 03, 1. all accepted, by design).
fun vj(lbl, s)
  try
    var n = s.getJson(json: 2);
    ?. 'PASS ' + lbl;
  except
    ?. 'FAIL ' + lbl + ' (rejected) :: ' + @;
  end try;
end fun;
fun badj(lbl, s)
  try
    var n = s.getJson(json: 2);
    ?. 'FAIL ' + lbl + ' (accepted)';
  except
    ?. 'PASS ' + lbl + ' :: ' + @;
  end try;
end fun;

?. '-- valid JSON must pass strict --';
vj('emptyobj ', '{}');
vj('emptyarr ', '[]');
vj('nested   ', '{"a":[1,{"b":2}],"c":null,"d":true,"e":false}');
vj('ws-nl    ', '{ "a" : 1 ,\n "b" : [ 1 , 2 ] }'.escape());
vj('ws-tab   ', '{\t"a"\t:\t1}'.escape());
vj('strbrk   ', '{"s":"a{b]c"}');
vj('numbers  ', '[-1.5e+3, 0, 0.5, 123]');
vj('escquote ', '{"s":"a\\"b"}'.escape());
vj('escslash ', '{"s":"a\\\\b"}'.escape());
vj('escuni   ', '{"s":"\u0041\u4e2d\n"}');
vj('dashes   ', '{"a": -1}');
vj('len-.5   ', '{"a":.5}');          // deliberate: lenient number grammar
vj('len-03   ', '[03]');              // deliberate
vj('len-1.   ', '[1.]');             // deliberate
vj('deep     ', '[[[[[[[[1]]]]]]]]');
?. '-- bare scalar roots are legal (RFC 8259) --';
vj('root-num ', '20');
vj('root-neg ', '-1.5');
vj('root-str ', '"hi"');
vj('root-true', 'true');
vj('root-fals', 'false');
vj('root-null', 'null');
?. '-- invalid must be caught --';
badj('unclosed['  , '[');
badj('unclosed{'  , '{"a":1');
badj('extra]'     , ']');
badj('extra}'     , '}');
badj('missval'    , '{"a":, "b":1}');
badj('str_uncl'   , '"abc');
badj('trailscalar', '{"a":1} 2');
badj('trailstr'   , '[1,2] "x"');
badj('badnum2'    , '{"a": 9z}');
badj('dotonly'    , '{"a":.}');
badj('dashonly'   , '{"a":-}');
badj('dotroot'    , '.');
badj('bareword'   , '[x]');
badj('empty'      , '');
badj('spaceonly'  , '  \n\t  '.escape());
?. '-- separator grammar (the rdb cases) --';
badj('trailcomma', '{"a":1,}');
badj('leadcomma ', '[,1]');
badj('duplcomma ', '[1,,2]');
badj('misscomma ', '[1 2]');
badj('misscomma2', '{"a":1 "b":2}');
badj('misscolon ', '{"a" 1}');
badj('dupcolon  ', '{"a"::1}');
badj('semicolon ', '{"a":1;}');
badj('equals    ', '{"a"=1}');
badj('sqstring  ', "{'a':1}");
badj('btstring  ', '{"a":`b`}');
badj('atdate    ', '{"a":@"2020-01-01"}');
badj('hexval    ', '{"a":0xff}');
badj('hexroot   ', '0x1f');
badj('nilval    ', '{"a":nil}');
badj('nilroot   ', 'nil');
?. '-- non-string keys --';
badj('barekey   ', '{a:1}');
badj('numkey    ', '{1:2}');
badj('arrkey    ', '{[1]:2}');
badj('nestedkey ', '{"a":{1:2}}');
?. '-- cross-bracket / structure --';
badj('cross1    ', '[1,2}');
badj('cross2    ', '{"a":1]');
badj('cross3    ', '[}');
badj('cross4    ', '{]');
?. '-- string grammar --';
badj('badesc    ', '{"a":"\q"}');
badj('badunicode', '{"a":"\u00"}');
badj('rawctrl   ', '{"a":"x\ny"}'.escape());
?. '-- json:2 + fd:true on FD --';
try
  var n = 'name zhang\nage 20'.escape().getJson(json: 2, fd: true);
  ?. 'PASS fd-valid :: ' + n.@toJson();
except
  ?. 'FAIL fd-valid :: ' + @;
end try;
try
  var n = '``xZZ'.getJson(json: 2, fd: true);
  ?. 'FAIL fixedlen accepted';
except
  ?. 'PASS fixedlen :: ' + @;
end try;
