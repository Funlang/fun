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

procedure _lgetapi(env: CEnv; exp: CExp; exps: CExps; val: PValue);

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
  wstrs: array of WideString;
  ret: QWord;
begin
  if CExps.count(exps) = 1 then
  begin
    e := exps.Item[0];
    if e.asObj is CSet then exps := CSet(e.asObj).items;
  end;

  n := CExps.count(exps);
  SetLength(at, n); SetLength(av, n); SetLength(slots, n);
  SetLength(strs, n); SetLength(wstrs, n);

  // Build one 8-byte (pointer-sized) slot per argument; libffi reads from it.
  // n/i/l/p and the string forms all pass as a GPR value. Floats/structs are
  // not yet supported (would need ffi_type_float/double + XMM routing).
  for i := 0 to n - 1 do
  begin
    at[i] := @ffi_type_pointer;
    slots[i] := 0;
    e := CExp(exps.Item[i]);
    case flag[i + 1] of
      's', 'a':
        begin
          strs[i] := AnsiString(e.asStr);
          if strs[i] <> '' then slots[i] := QWord(PtrUInt(@strs[i][1]));
        end;
      'w':
        begin
          wstrs[i] := WideString(e.asStr);
          if wstrs[i] <> '' then slots[i] := QWord(PtrUInt(@wstrs[i][1]));
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
      else // 'v', 'c', 'f'(unsupported) -> 0
        slots[i] := 0;
    end;
    av[i] := @slots[i];
  end;

  st := ffi_prep_cif(@cif, FFI_DEFAULT_ABI, n, @ffi_type_pointer, @at[0]);
  if st <> FFI_OK then raise EBase.Create('getapi: ffi_prep_cif failed');

  ret := 0;
  ffi_call(@cif, TFnProc(hfun), @ret, @av[0]);

  case flag[Length(flag)] of
    's', 'a': p_val^ := fun.str(PAnsiChar(PtrUInt(ret)));
    'w'     : p_val^ := fun.str(PWideChar(PtrUInt(ret)));
    'i', 'n', 'l': p_val^ := fun.int(LongInt(ret)); // low 32 bits (eax)
    else     p_val^ := PtrUInt(ret);                // 'p' / default
  end;
  result := p_val;
end;

end.
