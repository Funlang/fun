// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

# wrap root or load xml
class XmlDocument(root)
  fun load(fn)
    var dom = 'MsXml2.DomDocument'.newobj();
    dom.async = false;
    if fn.length() < 256 and fn.find() then
      result = dom.load(fn);
    else
      result = dom.loadXml(fn);
    end if;
    if result then
      root = dom.documentElement;
    else
      //?. fn.substr(len: 1024);
      var e = dom.parseError;
      raise 'ERROR: %s @(%s,%s,%s) %s'.format(e.srcText, e.line, e.linepos, e.filepos, e.reason);
    end if;
  end fun;

  fun each(f)   # f(this, curr, eachChild(start))
    e@ch(root);
    fun e@ch(n)
      curr = n; # save curr node, wrap this to curr
      f(this, curr, (start){
        try
          var s = n.childNodes;
          for i = start to s.length-1 do
            var si = s.item(i);
            if si.nodeType in [1, 3] then # Element, Text
              e@ch(si);
            end if;
          end do;
        except
          ?. '$@@().$@'.eval();
        end try;
      });
    end fun;
  end fun;

  fun toJson()
    result = new [];
    t0json(root, result);
    fun t0json(n, r)
      r.@ = n.nodeName;
      try
        var s = n.attributes;
        for i = 0 to s.length-1 do
          var si = s.item(i);
          r[si.nodeName] = si.text;
        end do;
      except
        ?. '$@@().$@'.eval();
      end try;

      try
        var s = n.childNodes;
        var $ = new [];
        for i = 0 to s.length-1 do
          var si = s.item(i);
          if si.nodeType in [1, 3] then # Element, Text
            var $i = new [];
            $.@add($i);
            t0json(si, $i);
          end if;
        end do;
        if $.@count() > 0 then
          r.$ = $;
        end if;
      except
        ?. '$@@().$@'.eval();
      end try;
    end fun;
  end fun;

  // current node
  //   pass this to each fun
  //   call curr.xx
  var curr       = nil;

  #var prop(name) = curr.getAttribute(name); #*
  var prop = (name){ //?, name;
    result = curr.getAttribute(name);
    try
      if nil = result then
        result = nil;
      end if;
    except
      ?. name;
    end try;
  }; #

  //var name()     = curr.nodeName; #*
  fun name()
    try
      return curr.nodeName;
    except //?, 0;
      return nil;
    end try;
  end fun; #
end class;

fun mergeXmlValues(values, eval, f, x)
  result = false;
  x = 'MsXml2.DomDocument'.newobj();
  x.async = false;
  x.load(f);
  x.PreserveWhitespace = false;
  var vName = values.@vName;
  if vName = nil then
    vName = 'value';
  end if;
  for k: v in values do next when k.length() > 1 and k.substr(0, 1) = '@';
    try
      v = eval(v); //?. k; ?. v; // 计算真实值
      var n = x.selectSingleNode(k);
      if n = nil or n.getAttribute(vName) <> v then
        if n <> nil then
          n.setAttribute(vName, v);
        else
          n = ensurePath(k.match(%^[^\[\]]++%).@@(), result);
          var m = k.match(/\[@([^=\]]++)\s*+=\s*+'([^']++)'\]/);
          if m then
            n.setAttribute(m.@(1), m.@(2));
          end if;
          n.setAttribute(vName, v);
          fun ensurePath(q, updated) ?, q;
            var p = q.replace(%/[^/]++$%, ''); ?. p;
            if p <> nil and x.selectSingleNode(p) = nil then
              ensurePath(p, updated);
            end if;
            n = x.selectSingleNode(p);
            result = x.createElement(q.match(%[^/]++$%).@@());
            if updated then
              n.appendChild(x.createTextNode('\t'.escape()));
            end if;
            n.appendChild(result);
            n.appendChild(x.createTextNode('\r\n'.escape()));
          end fun;
        end if;
        result = true;
      end if;
    except
      ?. @;
    end try;
  end do;
end fun;
