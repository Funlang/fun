// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

class Stream(fn, sz, cp)
  if fn <> nil then
    fn.move();
  end if;
  var first = true;

  if sz = nil then
    sz = 16 * 1024; // 16K 分批保存性能最好 (经验值, SSD 硬盘)
  end if;
  var ss  = 0.x(sz);
  var pos = 0;

  fun Write(s, l)
    result = 1;
    l = l or s.length();
    if pos + l > sz and fn <> nil then
      if pos > 0 then
        Save();
      end if;
      Save(s);
    else
      if pos + l > sz then
        while sz < pos + l do sz *= 2; end do;
        var so = ss;
        ss = 0.x(sz);
        so.movs(ss, pos);
      end if;
      s.movs(ss, l, pod: pos);
      pos += l;
    end if;
  end fun;

  fun Save(s)
    if s = nil then
      s = ss.substr(len: pos);
      pos = 0;
    end if;
    fn.save(s, cp: cp, append: not first);
    first = false;
  end fun;

  fun Get()
    result = ss.substr(len: pos);
  end fun;

  fun Reset()
    pos = 0;
  end fun;
end class;
