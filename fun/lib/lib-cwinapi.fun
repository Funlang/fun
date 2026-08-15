// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use "lib-cstruct.fun";

class CWin32API(dllName, funcProto, init)
  var @func = nil;
  var @params = new [];
  var @retFlag = 'i';

  # 注释剥离
  fun @stripComments(code)
    result = code.replace(%//[^\r\n]*+|/\*.*?\*/%gs, '');
  end fun;

  # ---------- 构造 ----------
  funcProto = this.@stripComments(funcProto);
  var parsed = this.@_parseProto(funcProto);
  var funcName = parsed.funcName;
  this.@params = parsed.params;
  this.@retFlag = parsed.retFlag;

  var sig = '';
  for p in this.@params loop sig &= p.flag; end loop;
  sig &= ':' & this.@retFlag;
  this.@func = dllName.getapi(funcName, sig);

  this.args = new [];
  for p, idx in this.@params loop
    var defVal = 0;
    if p.type = 'str_ptr' then defVal = ''; end if;
    if init != nil then
      if p.name != nil and init[p.name] != nil then defVal = init[p.name]; end if;
      if init[idx] != nil then defVal = init[idx]; end if;
    end if;
    if p.name != nil then
      this.args[p.name] = defVal;
    else
      this.args[idx] = defVal;
    end if;
  end loop;

  # ---------- 静态回调生成 ----------
  fun @callback(decl, func, opts)
    var m = decl.match(/^\s*([\w\s*]+)\s+(\w+)?\s*(?P<a>\((([^()]*|(?P>a))*)\))\s*$/);
    if not m then return 0; end if;
    var retType = m.@(1);
    var paramStr = m.@(4);

    var sig = '';
    if paramStr.replace(/^\s+|\s+$/g, '') != '' then
      var parts = split(/,/, paramStr);
      for p in parts loop
        p = p.replace(/^\s+|\s+$/g, '');
        next when p = '';
        var ti = CStruct.@typeInfo(p, 0);
        sig &= ti.type = 'num' and 'i' or 'p';
      end loop;
    end if;
    sig &= ':';
    var ri = CStruct.@typeInfo(retType, 0);
    sig &= ri.type = 'num' and 'i' or 'p';

    var obj = nil;
    var thread = false;
    var ptr = false;
    if opts != nil then
      if opts['obj'] != nil then obj = opts['obj']; end if;
      if opts['ptr'] != nil then ptr = opts['ptr']; end if;
      if opts['thread'] != nil then thread = opts['thread']; end if;
    end if;
    result = func.@toCallback(obj, sig, ptr, thread: thread);
  end fun;

  # ---------- 便捷汇编 ----------
  fun @asm(asmClass, sig, code, args, callbacks)
    var a = asmClass(sig, code, callbacks);
    result = a.Load().Run(args);
    a.Delete();
  end fun;

  # ---------- 调用 ----------
  var @call = call;
  fun call(ovars, opts)
    result = nil;
    var argvals = new [];

    for p in this.@params loop
      var val = nil;
      if ovars and p.name then
        val = ovars[p.name];
      end if;
      if val = nil then
        val = this.args[p.name or p.idx];
      end if;
      if val = nil then val = 0; end if;

      if p.type = 'num' then
        argvals.@add(val);
      elsif p.type = 'ptr' then
        if val.@toPtr != nil then argvals.@add(val.@toPtr()); else argvals.@add(val); end if;
      elsif p.type = 'struct_ptr' then
        if val and val.@toPtr then argvals.@add(val.@toPtr()); else argvals.@add(0); end if;
      elsif p.type = 'str_ptr' then
        # ★ 直接取字符串地址，当整数传入 ★
        argvals.@add(val.toNum(-1));
      elsif p.type = 'cb' then
        val = CWin32API.@callback(p.cbDecl, val, opts);
        argvals.@add(val);
      else
        argvals.@add(val);
      end if;
    end loop;

    if this.@func != nil then result = this.@func.call(argvals); end if;

    # 刷新输出参数
    for p in this.@params loop
      if p.type = 'struct_ptr' then
        var obj = this.args[p.name or p.idx];
        if obj != nil and obj.@toFun != nil then obj.@toFun(); end if;
      end if;
    end loop;
  end fun;

  # ---------- 原型解析 ----------
  fun @_parseProto(proto)
    var m = proto.match(/^\s*([\w\s*]+)\s+(\w+)\s*(?P<a>\((([^()]*|(?P>a))*)\))\s*;?\s*$/);
    if not m then return new [ params: new [], retFlag: 'i', funcName: '' ]; end if;
    var retType = m.@(1);
    var funcName = m.@(2);
    var paramStr = m.@(4);

    var ri = CStruct.@typeInfo(retType, 0);
    var rFlag = 'i';
    if ri.type = 'str_ptr' then rFlag = ri.encoding = 'ansi' and 'a' or 'w'; end if;
    if ri.type = 'ptr' or ri.type = 'struct_ptr' then rFlag = 'p'; end if;

    var params = new [];
    if paramStr.replace(/^\s+|\s+$/g, '') != '' and paramStr != 'void' then
      var parts = paramStr.match(/([^(),]++|\(([^()]++|(?R))\))++/g);
      var idx = 0;
      for p in parts loop
        p = p.replace(/^\s+|\s+$/g, '');
        next when p = '';
        var fm = p.match(/^\s*(.+)\s+(\w+)\s*$/);
        var ctype;
        var pname;
        if fm then
          ctype = fm.@(1);
          pname = fm.@(2);
        else
          ctype = p;
          pname = nil;
        end if;
        var ti = CStruct.@typeInfo(ctype, 0);
        var pflag = ti.type = 'cb' and 'c' or 'i';   // ★ 除回调外全部用 'i'
        params.@add(new [
          name: pname,
          idx: idx,
          type: ti.type,
          flag: pflag,
          size: ti.size,
          signed: ti.signed,
          encoding: ti.encoding,
          structName: ti.structName,
          cbDecl: ti.cbDecl or ''
        ]);
        idx += 1;
      end loop;
    end if;
    return new [ params: params, retFlag: rFlag, funcName: funcName ];
  end fun;
end class;