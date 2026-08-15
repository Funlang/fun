// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use "lib-regex.fun";
use "lib-utils.fun";
use "lib-math.fun";

var _structSizeMap = new [];

# ========== 类型映射规则表 ==========
var _typeRules = [
  [/^(lpstr|lpcstr|pcstr|char\*|const\s*char\*)$/i, 'str_ptr', 4, 'ansi'],
  [/^(lpwstr|lpcwstr|pcwstr|wchar\*|const\s*wchar\*)$/i, 'str_ptr', 4, 'wide'],
  [/^(lptstr|lpctstr|ptstr|pctstr)$/i, 'str_ptr', 4, nil],
  [/^(void\*|lpvoid|pvoid|handle|hwnd|hmodule|hicon|hcursor|hbrush|hdc|lpdword|lparam|wparam|lresult)$/i, 'num', 4, nil],
  [/^LP\w|\*$/i, 'struct_ptr', 4, nil],
  [/PROC$/i, 'cb', 4, nil],
  [/^(char|byte)$/i, 'num', 1, nil],
  [/^(short|int16)$/i, 'num', 2, nil],
  [/^(int|long|bool|boolean|dword|ulong|uint|int32)$/i, 'num', 4, nil],
];

class CStruct(@decl, @init, @customSize)
  var @fields = new [];
  var @buf = '';
  var @totalSize = 0;
  var @pinned = new [];

  # ---------- 静态方法 ----------
  fun @parse(decl)
    decl = CStruct.@stripComments(decl);
    result = CStruct.@_parseStruct(decl);
  end fun;

  fun @register(name, decl)
    decl = CStruct.@stripComments(decl);
    if _structSizeMap[name] = nil then
      _structSizeMap[name] = CStruct.@parse(decl).totalSize;
    end if;
  end fun;

  fun @sizeOf(name)
    if _structSizeMap[name] != nil then result = _structSizeMap[name]; else result = 0; end if;
  end fun;

  fun @typeInfo(ctype, arrlen)
    result = CStruct.@_mapType(ctype, arrlen);
  end fun;

  # ---------- 字段解析 ----------
  fun @_parseFields(text, delimiter)
    var parts = split(delimiter, text);
    var fields = new [];
    var curOff = 0;
    var maxAlign = 1;

    for p in parts loop
      p = p.replace(/^\s+|\s+$/g, '');
      next when p = '';
      var fm = p.match(/^\s*(.+)\s+(\w+)(\s*\[(\d+)\])?\s*$/);
      next when not fm;
      var ctype = fm.@(1);
      var name = fm.@(2);
      var arrlen = 0;
      if fm.@(4) != nil then arrlen = fm.@(4) * 1; end if;

      var ti = CStruct.@_mapType(ctype, arrlen);
      var size = ti.size;

      var align = 1;
      if ti.type = 'num' or ti.type = 'ptr' or ti.type = 'str_ptr' or ti.type = 'struct_ptr' or ti.type = 'cb' then
        align = min(size, 4);
      elsif ti.type = 'str_fixed' then
        align = ti.encoding = 'wide' and 2 or 1;
      elsif ti.type = 'struct' then
        align = 4;
      end if;
      if align > maxAlign then maxAlign = align; end if;

      while curOff mod align != 0 loop curOff += 1; end loop;

      var fd = new [ name: name, off: curOff, type: ti.type, size: ti.size ];
      if ti.type = 'num' then fd.signed = ti.signed; end if;
      if ti.type = 'str_ptr' or ti.type = 'str_fixed' then fd.encoding = ti.encoding; end if;
      if ti.type = 'struct' or ti.type = 'struct_ptr' then fd.structName = ti.structName; end if;
      if ti.type = 'cb' then fd.cbDecl = ti.cbDecl; end if;
      fields.@add(fd);
      curOff += size;
    end loop;

    while curOff mod maxAlign != 0 loop curOff += 1; end loop;
    result = new [ fields: fields, totalSize: curOff ];
  end fun;

  # ---------- 私有构造初始化 ----------
  this.@_initFromDecl(@decl, @init, @customSize);

  fun @_initFromDecl(decl, init, customSize)
    var parsed;
    if decl.toStr() then parsed = CStruct.@parse(decl); else parsed = decl; end if;
    this.@fields = parsed.fields;
    this.@totalSize = parsed.totalSize;
    if customSize != nil then this.@totalSize = customSize; end if;

    var sizeField = nil;
    if init != nil and init['@size'] != nil then sizeField = init['@size']; end if;

    for fd in this.@fields loop
      var defVal = 0;
      if fd.type = 'str_ptr' or fd.type = 'cb' then defVal = ''; end if;
      if fd.type = 'str_fixed' then defVal = ''; end if;
      if fd.type = 'struct' then defVal = nil; end if;
      var val = defVal;
      if init != nil and init[fd.name] != nil then val = init[fd.name]; end if;
      if sizeField != nil and fd.name = sizeField then val = this.@totalSize; end if;
      this[fd.name] = val;
    end loop;
  end fun;

  # ========== 序列化：流式累加写入 ==========
  fun @toPtr()
    this.@pinned = new [];
    this.@buf = 0.toChar().x( ceil(this.@totalSize / charSize()) );
    var curPos = 0.0;

    for fd in this.@fields loop
      while (curPos * charSize()) < fd.off loop
        curPos += 1.0 / charSize();
      end loop;

      var val = this[fd.name];
      if val = nil then val = 0; end if;

      if fd.type = 'struct_ptr' then
        if val and val.@toPtr != nil then val = val.@toPtr(); end if;
        goBytes(this.@buf, fd.size, (b,i,j){ b[curPos + i] = (val >> (j * 8)) bit and 0xFF; });
        curPos += fd.size / charSize();
      elsif fd.type = 'num' or fd.type = 'ptr' or fd.type = 'str_ptr' or fd.type = 'cb' then
        goBytes(this.@buf, fd.size, (b,i,j){ b[curPos + i] = (val >> (j * 8)) bit and 0xFF; });
        curPos += fd.size / charSize();
      elsif fd.type = 'str_fixed' then
        var ansi = val.toStr(0);
        goBytes(this.@buf, fd.size, (b,i,j){ b[curPos + i] = j < ansi.length() and ansi.toByte(j) or 0; });
        curPos += fd.size / charSize();
      elsif fd.type = 'struct' then
        if val != nil then
          val.@toPtr();
          goBytes(this.@buf, fd.size, (b,i,j){ b[curPos + i] = val.@buf[i]; });
          curPos += fd.size / charSize();
        end if;
      end if;
    end loop;

    result = this.@buf.toNum(-1);
  end fun;

  # ========== 反序列化：字符偏移直接解析 ==========
  fun @toFun()
    if this.@buf = '' then return; end if;

    for fd in this.@fields loop
      var val;
      var off = fd.off / charSize();

      case fd.type is
        when 'num' do          val = this.@_readNum(off, fd.size, fd.signed);
        when ['ptr', 'struct_ptr', 'cb'] do val = this.@_readNum(off);
        when 'str_ptr' do      val = this.@_readNum(off);
        when 'str_fixed' do    val = this.@_readStr(off, fd.size);
        when 'struct' do
          var sub = this[fd.name];
          if sub != nil then
            sub.@buf = 0.toChar().x( ceil(fd.size / charSize()) );
            goBytes(this.@buf, fd.size, (b,i,j){ sub.@buf[i] = b[off + i]; });
            sub.@toFun();
            val = sub;
          end if;
      end case;
      this[fd.name] = val;
    end loop;
  end fun;

  # ========== 内部读写原语 ==========
  fun @_readNum(off, size, signed)
    size = size or 4;
    var v = 0;
    goBytes(this.@buf, size, (b,i,j){ v = v bit or (b[off + i] << (j * 8)); });
    result = toSigned(v, size, signed);
  end fun;

  fun @_readStr(off, size)
    var res = '';
    goBytes(this.@buf, size, (b,i,j){
      var byte = b[off + i];
      if byte = 0 then return true; end if;
      res &= byte.toChar();
    });
    result = res;
  end fun;

  fun @stripComments(code)
    result = code.replace(%//[^\r\n]*+|/\*.*?\*/%gs, '');
  end fun;

  fun @_parseStruct(decl)
    var m = decl.match(/struct\s+(\w+)\s*\{([^}]*)\}/s);
    if not m then return new [ fields: new [], totalSize: 0 ]; end if;
    result = CStruct.@_parseFields(m.@(2), /;/);
  end fun;

  # ========== 类型映射 ==========
  fun @_mapType(ctype, arrlen)
    var t = ctype.replace(/\bconst\b/g, '').replace(/^\s+|\s+$/g, '');
    t = t.replace(/\s+/g, ' ');

    if t =~ /^struct\s+/i then
      t = t.replace(/^struct\s+/i, '');
      return new [ type: 'struct', structName: t, size: CStruct.@sizeOf(t) ];
    end if;

    var isUnsigned = false;
    if t.subpos('unsigned') = 0 then
      isUnsigned = true;
      t = t.replace(/^unsigned\s+/, '');
    end if;

    if arrlen > 0 then
      if t =~ /^(char|byte)$/i then return new [ type: 'str_fixed', encoding: 'ansi', size: arrlen ];
      elsif t =~ /^(wchar|wchar_t)$/i then return new [ type: 'str_fixed', encoding: 'wide', size: arrlen * 2 ];
      else return new [ type: 'str_fixed', encoding: 'ansi', size: arrlen ]; end if;
    end if;

    for rule in _typeRules loop
      next when not t =~ rule[0];
      var kind = rule[1];
      var sz   = rule[2] or 4;
      var enc  = rule[3];
      if kind = 'str_ptr' then
        var encoding = enc;
        if encoding = nil then encoding = isUnicode() and 'wide' or 'ansi'; end if;
        return new [ type: 'str_ptr', encoding: encoding, size: 4 ];
      elsif kind = 'struct_ptr' then
        var sname = t;
        if t =~ /^LP\w/i then sname = t.replace(/^LP/i, '');
        elsif t.subpos('*') != -1 then sname = t.replace(/\*$/, '').trim(); end if;
        if sname != '' and CStruct.@sizeOf(sname) > 0 then
          return new [ type: 'struct_ptr', structName: sname, size: sz ];
        else
          return new [ type: 'num', size: sz ];
        end if;
      elsif kind = 'cb' then
        return new [ type: 'cb', size: sz, cbDecl: '' ];
      else
        return new [ type: 'num', signed: not isUnsigned, size: sz ];
      end if;
    end loop;

    if t.subpos('(') != -1 then
      var fm = t.match(/^\s*([\w\s*]+)\s+(\w+)?\s*\(([^)]*)\)\s*$/);
      if fm then return new [ type: 'cb', size: 4, cbDecl: t ]; end if;
    end if;

    return new [ type: 'num', signed: not isUnsigned, size: 4 ];
  end fun;
end class;