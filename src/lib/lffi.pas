// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
unit lffi;

// Linux FFI: load a native shared object and call an exported function by
// signature, backed by libffi (FPC's bundled `ffi` unit). This is the Linux
// counterpart of the Windows winapi unit. winapi.pas stays Windows-only and is
// isolated behind the WinAPI define; this unit is built only for Linux.

interface

uses fun, base, core, host,
     dynlibs,
     ffi;

type
  // Handler added to env.libs: routes calls on a getapi() result object.
  CLffiApi = class(CLib)
  public
    function accept(exp: CExp): fun.bool; override;
    function call(env: CEnv; exp: CExp; const id: fun.str; exps: CExps; val: PValue; ct: fun.byte = CDoMethod): fun.bool; override;
  end;

  // A resolved native function; the value returned by f.getapi(...).
  CFFIFun = class(CExp)
  private
    flag: fun.str;     // type string, e.g. 'ss:i'
    hfun: fun.ptr;     // symbol address (dlsym result)
    hlib: TLibHandle;  // dlopen handle (released on destroy)
  public
    constructor Create(alib: TLibHandle; afun: fun.ptr; const atype: fun.str);
    destructor Destroy; override;
    function call(env: CEnv; exps: CExps): PValue; override;
  end;

  // A Fun function wrapped as a native callable via a libffi closure. Returned
  // by f.@toCallback(type) and handed to C functions that take a function
  // pointer (matched in getapi() with a 'c' argument type).
  CFFICallback = class(CCallObj)
  private
    FClos: Pointer;         // libffi closure block (freed on destroy)
    FCode: Pointer;         // executable entry point returned to C
    FTypes: fun.str;        // '<argchars...>:<retchar>' from @toCallback
    FArgs: fun.str;         // argument type chars
    FRet: Char;             // return type char
    FCif: ffi_cif;          // kept alive for the whole closure lifetime
    FAt: array of Pffi_type;// closure arg types (persisted for the cif)
    FStr: AnsiString;       // keeps the last string return alive
    function Build: Pointer;
    function GetProc: Pointer;
  protected
    function Parse(exp: CExp; exps: CExps; theEnv: CEnv): CFFICallback;
  public
    destructor Destroy; override;
    procedure Invoke(cif: Pffi_cif; resp: Pointer; args: PPointer);
    property Proc: Pointer read GetProc;
  end;

procedure _lgetapi(env: CEnv; exp: CExp; exps: CExps; val: PValue);
procedure _ltoCallback(env: CEnv; exp: CExp; exps: CExps; val: PValue);

implementation

uses SysUtils;

type PValue = base.PValue;

// f.getapi(name, type)
procedure _lgetapi(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  name: fun.str;
  hlib: TLibHandle;
  hfun: fun.ptr;
  f: CFFIFun;
  e: CExp;
begin
  hlib := NilHandle;
  name := exp.asStr;
  if name <> '' then
  begin
    hlib := LoadLibrary(name);
    if (hlib = NilHandle) and (Pos('/', name) = 0) and (Pos('.so', name) = 0) then
      hlib := LoadLibrary(name + '.so'); // bare name, e.g. 'libc'
  end;

  hfun := nil;
  e    := CExps.Find(exps, 'name', 0);
  if e <> nil then
  begin
    if isNum(e.value) then
      hfun := fun.ptr(fun.uint(e.value^))
    else
      name := e.asStr
    ;
  end;
  if hfun = nil then
  begin
    if (hlib = NilHandle) or (name = '') then
      raise EBase.Create('getapi: cannot load library / symbol');
    hfun := fun.ptr(GetProcedureAddress(hlib, name));
  end;
  f := CFFIFun.Create(hlib, hfun, CExps.FindAsVal(exps, 'type', 1, ''));
  setObj(val, f, VarObjNew); del(f);
end;

//==============================================================
function CLffiApi.accept(exp: CExp): fun.bool;
begin
  result := exp.asObj is CFFIFun;
end;

function CLffiApi.call(env: CEnv; exp: CExp; const id: fun.str; exps: CExps; val: PValue; ct: fun.byte = CDoMethod): fun.bool;
begin
  // id = 'call'
  // x.call(...)
  // x(...)
  val^ := CFFIFun(exp.asObj).call(env, exps)^;
  result := true;
end;

//==============================================================
constructor CFFIFun.Create(alib: TLibHandle; afun: fun.ptr; const atype: fun.str);
begin
  inherited new(nil);
  hlib := alib;
  hfun := afun;
  flag := atype;
end;

destructor CFFIFun.Destroy;
begin
  if hlib <> NilHandle then UnloadLibrary(hlib);
  inherited Destroy;
end;

type
  TFnProc = procedure; register; // generic callable address for libffi

function CFFIFun.call(env: CEnv; exps: CExps): PValue;
var
  e: CExp;
  n, i: Integer;
  cif: ffi_cif;
  st: ffi_status;
  at: array of Pffi_type;
  av: array of Pointer;
  slots: array of QWord;
  strs: array of AnsiString;
  ch, rt: Char;
  ret: QWord;
  rtype: Pffi_type;
begin
  if CExps.count(exps) = 1 then
  begin
    e := exps.Item[0];
    if e.asObj is CSet then exps := CSet(e.asObj).items;
  end;

  n := CExps.count(exps);
  SetLength(at, n); SetLength(av, n); SetLength(slots, n);
  SetLength(strs, n);

  // Build one 8-byte slot per argument; libffi reads from it. Integer/pointer
  // and the string forms pass as GPR values (ffi_type_pointer), doubles route
  // through the SSE register file (ffi_type_double). Each slot is 8 bytes and
  // 8-aligned, so both kinds fit in the same QWord array.
  for i := 0 to n - 1 do
  begin
    at[i] := @ffi_type_pointer;
    slots[i] := 0;
    av[i] := @slots[i];
    e := CExp(exps.Item[i]);
    ch := flag[i + 1];
    case ch of
      's', 'a':
        begin
          strs[i] := AnsiString(e.asStr);
          if strs[i] <> '' then slots[i] := QWord(PtrUInt(@strs[i][1]));
        end;
      'w': // wide string unsupported on Linux (wchar_t is 4-byte UTF-32)
        raise EBase.Create('getapi: wide-string (w) not supported on Linux FFI');
      'c': // callback: pass a Fun callback's native entry point
        begin
          if e.asObj is CFFICallback then slots[i] := QWord(PtrUInt(CFFICallback(e.asObj).Proc))
          else if isNum(e.value, true) then slots[i] := QWord(e.value^)
          else if e.asObj <> nil then slots[i] := QWord(PtrUInt(e.asObj));
        end;
      'f': // single (float32) argument (SSE)
        begin
          at[i] := @ffi_type_float;
          if isNum(e.value, true) then PSingle(@slots[i])^ := Double(e.value^)
          else PSingle(@slots[i])^ := 0;
        end;
      'd': // double argument (SSE)
        begin
          at[i] := @ffi_type_double;
          if isNum(e.value, true) then PDouble(@slots[i])^ := Double(e.value^)
          else PDouble(@slots[i])^ := 0;
        end;
      'n', 'i', 'l':
        begin
          if isNum(e.value) then slots[i] := QWord(e.value^)
          else if e.asObj <> nil then slots[i] := QWord(PtrUInt(e.asObj));
        end;
      'p':
        begin
          if isStr(e.value) then
            slots[i] := QWord(PtrUInt(Pointer(AnsiString(e.asStr))))
          else if isNum(e.value) then
            slots[i] := QWord(e.value^)
          else if e.asObj <> nil then
            slots[i] := QWord(PtrUInt(e.asObj));
        end;
      else // 'v', 'c' -> 0
        slots[i] := 0;
    end;
  end;

  // select the libffi return type from the last type char
  rt := flag[Length(flag)];
  if rt = 'w' then raise EBase.Create('getapi: wide-string (w) return not supported on Linux FFI');
  case rt of
    'f': rtype := @ffi_type_float;
    'd': rtype := @ffi_type_double;
    'v': rtype := @ffi_type_void;
  else rtype := @ffi_type_pointer;
  end;
  st := ffi_prep_cif(@cif, FFI_DEFAULT_ABI, n, rtype, @at[0]);
  if st <> FFI_OK then raise EBase.Create('getapi: ffi_prep_cif failed');

  ret := 0;
  if rt = 'v' then ffi_call(@cif, TFnProc(hfun), nil, @av[0])
  else ffi_call(@cif, TFnProc(hfun), @ret, @av[0]); // 8-byte resp buffer holds f/d too

  case rt of
    'f': p_val^ := PSingle(@ret)^;
    'd': p_val^ := PDouble(@ret)^;
    's', 'a': p_val^ := fun.str(PAnsiChar(PtrUInt(ret)));
    'i'     : p_val^ := fun.int(LongInt(ret));      // C int (low 32 bits / eax)
    'l', 'n': p_val^ := Int64(ret);                 // C long / 64-bit number
    'v'     : p_val^ := NullValue;
  else     p_val^ := PtrUInt(ret);                   // 'p' / default
  end;
  result := p_val;
end;

//==============================================================
// f.fn.@toCallback(obj, type, ptr)
//   type -> '<argchars...>:<retchar>', e.g. ':i', 'ii:i', 'd:d'
//   arg chars: i(nt32) l(ong64)/n(umber64) f(loat32) d(ouble) s/a(char*) p/c(pointer)
//   ret chars: same plus v(void). Wide char 'w' is not supported on Linux
//   (wchar_t is 4-byte UTF-32). cdecl (SysV) is always used.
procedure _ltoCallback(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  c: CFFICallback;
  e: CExp;
begin
  c := CFFICallback.Create.Parse(exp, exps, env);
  e := CExps.Find(exps, 'ptr', 2);
  if (e <> nil) and e.asBool then
    val^ := Int64(PtrUInt(c.Proc)) // raw address escape hatch; object stays alive
  else
  begin
    setObj(val, c, VarObjNew); del(c);
  end;
end;

// libffi closure entry: native code calls FCode -> libffi trampoline -> this.
procedure CFFITrampoline(cif: Pffi_cif; resp: Pointer; args: PPointer; user: Pointer); cdecl;
begin
  if user <> nil then CFFICallback(user).Invoke(cif, resp, args);
end;

function CFFICallback.Parse(exp: CExp; exps: CExps; theEnv: CEnv): CFFICallback;
begin
  inherited parse(exp, exps, theEnv);
  FTypes := CExps.FindAsVal(exps, 'type', 1, '');
  result := self;
end;

destructor CFFICallback.Destroy;
begin
  if FClos <> nil then ffi_closure_free(FClos);
  FClos := nil;
  inherited Destroy;
end;

function CFFICallback.Build: Pointer;
var
  p, i: Integer;
  rtype: Pffi_type;
  st: ffi_status;
begin
  if FCode <> nil then exit(FCode);

  p := Pos(':', FTypes);
  if p = 0 then
  begin
    FArgs := '';
    FRet  := 'v';
  end
  else
  begin
    FArgs := Copy(FTypes, 1, p - 1);
    if p < Length(FTypes) then FRet := FTypes[p + 1] else FRet := 'v';
  end;

  SetLength(FAt, Length(FArgs));
  for i := 1 to Length(FArgs) do
    if FArgs[i] = 'w' then
      raise EBase.Create('toCallback: wide-string (w) not supported on Linux FFI')
    else
    case FArgs[i] of
      'i': FAt[i - 1] := @ffi_type_sint32;
      'l', 'n': FAt[i - 1] := @ffi_type_sint64;
      'f': FAt[i - 1] := @ffi_type_float;
      'd': FAt[i - 1] := @ffi_type_double;
    else FAt[i - 1] := @ffi_type_pointer; // p/c/s/a
    end;

  if FRet = 'w' then raise EBase.Create('toCallback: wide-string (w) not supported on Linux FFI');
  case FRet of
    'i': rtype := @ffi_type_sint32;
    'l', 'n': rtype := @ffi_type_sint64;
    'f': rtype := @ffi_type_float;
    'd': rtype := @ffi_type_double;
    'c', 'p', 's', 'a': rtype := @ffi_type_pointer;
  else rtype := @ffi_type_void; // 'v'
  end;

  if Length(FArgs) > 0 then
    st := ffi_prep_cif(@FCif, FFI_DEFAULT_ABI, Length(FArgs), rtype, @FAt[0])
  else
    st := ffi_prep_cif(@FCif, FFI_DEFAULT_ABI, 0, rtype, nil);
  if st <> FFI_OK then raise EBase.Create('toCallback: ffi_prep_cif failed');

  FClos := ffi_closure_alloc(SizeOf(ffi_closure), @FCode);
  if FClos = nil then raise EBase.Create('toCallback: ffi_closure_alloc failed');

  st := ffi_prep_closure_loc(FClos, @FCif, @CFFITrampoline, Pointer(self), FCode);
  if st <> FFI_OK then raise EBase.Create('toCallback: ffi_prep_closure_loc failed');
  result := FCode;
end;

function CFFICallback.GetProc: Pointer;
begin
  result := Build;
end;

procedure CFFICallback.Invoke(cif: Pffi_cif; resp: Pointer; args: PPointer);
var
  es: CExps;
  e: CExp;
  i, na: Integer;
  ch: Char;
  rv: PValue;
begin
  es := CExps.Create();
  try
    na := Length(FArgs);
    for i := 0 to na - 1 do
    begin
      e := CExp.new(nil);
      es.Add(e);
      ch := FArgs[i + 1];
      case ch of
        'i': e.assign(PLongInt(args[i])^);
        'l', 'n': e.assign(PInt64(args[i])^);
        'f': e.assign(PSingle(args[i])^);
        'd': e.assign(PDouble(args[i])^);
        'w': e.assign(fun.str(PWideChar(PPointer(args[i])^)));
        's', 'a': e.assign(fun.str(PAnsiChar(PPointer(args[i])^)));
        'c', 'p': e.assign(Int64(PtrUInt(PPointer(args[i])^)));
      else e.assign(0);
      end;
    end;

    rv := call(self.env, es); // evaluate the wrapped Fun function
    if (resp = nil) or (rv = nil) then exit;

    case FRet of
      'v': ; // void
      'i':
        if isFloat(rv) then PLongInt(resp)^ := Trunc(Double(rv^))
        else if isNum(rv) then PLongInt(resp)^ := LongInt(rv^)
        else PLongInt(resp)^ := 0;
      'l', 'n':
        if isFloat(rv) then PInt64(resp)^ := Trunc(Double(rv^))
        else if isNum(rv) then PInt64(resp)^ := Int64(rv^)
        else PInt64(resp)^ := 0;
      'f': PSingle(resp)^ := Double(rv^); // auto-converts to Single
      'd': PDouble(resp)^ := Double(rv^);
      'p', 'c': PPointer(resp)^ := Pointer(PtrUInt(Double(rv^)));
      's', 'a':
        begin
          FStr := fun.str(rv^); // keep the returned string alive
          if FStr <> '' then PPointer(resp)^ := PAnsiChar(@FStr[1])
          else PPointer(resp)^ := nil;
        end;
    end;
  finally
    del(es);
  end;
end;

end.
