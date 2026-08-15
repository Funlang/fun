// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-os.fun';

//==============================================================
// Param
//   -p:...
//   /a=...
//==============================================================
fun GetCmdLineParams()
  result = new [];

  var s = 'kernel32'.getapi('GetCommandLine', ':s').call(); //?. s;
  var m = s.match(/("([^"]*+|"")++"|[^"\s]++)++/g); //?. m.@toJson();
  result.@exe = escape(m[0]);
  if result.@exe =~ /\\/ then
    result.@path = result.@exe.replace(/[^\\]++$/, '');
  else
    result.@path = GetCurrPath() & '\';
  end if;

  var i = 0;
  for p in m do //?. p;
    if p =~ %^"?[-/][pPaA@][:=]% then
      return ParseJsonLite(p.replace(%^(?P<q>"?)[-/][pPaA@][:=](?P<p>.*?)(?P=q)$%gs, '${p}'), result);
    elsif i = 1 then
      result.@fun = escape(p);
    end if;
    i += 1;
  end do;
end fun;
var CmdLineParams = GetCmdLineParams();

fun escape(s)
  return s.replace(/^"|"$|(?=")"/g, '');
end fun;

fun ViewCmdLineParams()
  for k:v in CmdLineParams do
    ?. '$k\t$v'.escape().eval();
  end do;
end fun;

//==============================================================
// Json Lite (Seperated by [,;] and key [:=] value), e.g.:
//  Params of CmdLine => -p:debug=true,log:xxx;...
//   key=value,debug;auto:true
//  Fun Data Bind     => fun:data="url" or fun:data="url=value"
//   url=value,r,w,load:UrlLoad;save=UrlSave
//   res.Title=innerText,r
//==============================================================
fun ParseJsonLite(s, set) //?. s;
  var ret = set;
  if ret = null then
    ret = new [];
  end if;
  result = ret;

  s.match(/(?P<k>[@\w\.]++)(?:\s*+[:=]\s*+(?P<v>"[^"]*+"|'[^']*+'|`[^`]*+`|[^,;\s]++))?/g, (p){
    var k = p.@('k');
    var v = p.@('v');
    if v = nil then
      v = true;
    elsif v =~ /^["'`]/ then
      v = v.substr(1, - 2);
    end if;
    ret[k] = v;
  });
end fun;

// UnCascade(var set, var ids)
//  a.b.c.d.e
fun UnCascade(set, ids)
  ids.match(/[^\.]++(?!$)/g, (m){
    set = set[m.@@()];
    ids = m.rest().substr(1);
  });
end fun;
