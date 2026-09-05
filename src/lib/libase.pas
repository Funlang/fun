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
unit libase;

interface

uses fun, base, core, host;

type
  CLbase = class(CLib)
  public
    constructor Create;
    function accept(exp: CExp): fun.bool; override;
  end;
  

implementation

{$IfDef Unicode}{$WARN WIDECHAR_REDUCED OFF}{$EndIf}

uses SysUtils, Variants, {$IfNDef Linux}Windows,{$Else}Linux, unixtype,{$EndIf}
     io, parse
     {$IfDef WinCOM}  , winole  {$EndIf}
     {$IfDef WinAPI}  , winapi  {$EndIf}
     {$IfDef LinuxFFI}, lffi    {$EndIf}
     {$IfDef Regex}   , regex   {$EndIf}
     ;
type PValue = base.PValue;

//==============================================================
// 'I am'.@uthor()
// '....'.@uthor()
procedure _author(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  david: fun.str;
  i: fun.int;
begin
  if exp.asStr <> 'I am' then
  begin
    val^ := 'Wisdom ZHANG';
    exit;
  end;

  david := 'Ykbmd,Tfjglmd'; //'Zhang/Weidong';
  for i := 1 to Length(david) do
    david[i] := fun.char(fun.byte(david[i]) xor 3);
  ;
  val^  := david;
end;

//==============================================================
// 0.arg()
// 1.arg()
procedure _arg(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  i: fun.int;
begin
  i := exp.asInt;
  val^ := ParamStr(i);
end;

//==============================================================
// 'defaultCodePage'.set(936)
procedure _set(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  if exp.asStr = 'defaultCodePage' then
  begin
    defaultCodePage := CExps.FindAsVal(exps, '', 0, 0);
  end;
end;

//==============================================================
procedure _exp(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := System.Exp(exp.value^);
end;

procedure _log(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := System.Ln(exp.value^);
end;

procedure _sin(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := System.Sin(exp.value^);
end;

procedure _cos(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := System.Cos(exp.value^);
end;

procedure _atan(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := System.ArcTan(exp.value^);
end;

// 1.random(), 0.random(), a.random(), -1.random(seed = 0)
procedure _random(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  i, j: fun.int;
begin
  i := exp.asInt;
  if i > 1 then
    val^ := System.Random(i)
  else if i = -1 then
  begin
    j := CExps.FindAsVal(exps, 'seed', 0, 0);
    if j = 0 then
      val^ := RandSeed
    else
      RandSeed := j
    ;
  end
  else
  begin
    if i <= 0 then System.Randomize;
    val^ := System.Random;
  end;
end;

//==============================================================
procedure _length(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := Length(exp.asStr);
end;

procedure _lower(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := LowerCase(exp.asStr);
end;

procedure _upper(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := UpperCase(exp.asStr);
end;

// a.subpos(sub)
procedure _subpos(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  i: fun.int;
  s: fun.str;
begin
  i := -1;
  if CExps.Count(exps) > 0 then
  begin
    s := CExp(exps.Item[0]).asStr;
    i := Pos(s, exp.asStr) - 1;
  end;
  val^ := i;
end;

// a.substr(pos = 0, len = MAX)
procedure _substr(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  i, j, ii: fun.int;
  s: fun.str;
begin
  i := CExps.FindAsVal(exps, 'pos', 0, 0);
  j := CExps.FindAsVal(exps, 'len', 1, MaxInt);
  s := exp.asStr;
  ii := Length(s);
  i := calcIndex(i, ii);
  j := calcIndex(j, ii);
  val^ := Copy(s, i+1, j);
end;

// a.x(n), if n = -1 reverse it, -2 sort it
procedure _x(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  i, ii, l: fun.int;
  s, ss: fun.str;
  p: PChar;

  procedure sort();
  var
    nums: array of fun.int;
    i, j: fun.int;
  begin
    SetLength(nums, 256);
    for i := 1 to l do
    begin
      Inc(nums[Ord(s[i])]);
    end;
    SetLength(ss, l);
    ii := 1;
    for i := 0 to 255 do
    begin
      for j := 1 to nums[i] do
      begin
        ss[ii] := fun.char(i);
        Inc(ii);
      end;
    end;
    SetLength(nums, 0);
  end;
begin
  ii := CExps.FindAsVal(exps, '', 0, 0);
  s  := exp.asStr;
  l  := Length(s);
  if ii >= 0 then
  begin
    SetLength(ss, l * ii);
    if l * ii > 0 then
    begin
      p := fun.ptr(ss);
      for i := 0 to ii-1 do
      begin
        Move(fun.ptr(s)^, p^, l*SizeOf(Char));
        Inc(p, l);
      end;
    end;
  end
  else if ii = -1 then
  begin
    SetLength(ss, l);
    for i := 0 to l-1 do ss[i+1] := s[l-i];
  end
  else if ii = -2 then
  begin
    sort();
  end;
  val^ := ss;
end;

  // \b \t \n \f \r
  // \" \' \` \/ \\
  // \xHH
  // \uHHHH
  function esc(const s: fun.str): fun.str;
  var
    i, j, p, ii: fun.int;
    c: fun.char;
  begin
    ii := Length(s);
    SetLength(result, ii);
    i  := 1;
    j  := 1;
    while i <= ii do
    begin
      c := s[i];
      if (c = '\') and (i < ii) then
      begin
        Inc(i);
        c := s[i];
        p := Pos(c, 'btnvfr');
        if (p > 0) and (p <> 4) then
          result[j] := fun.char(8 + p - 1) // #8..#13
        else if c in ['"', '''', '`', '/', '\'] then
          result[j] := c
        else if (c = 'x') and (i+1 < ii) then
        begin
          result[j] := fun.char(StrToInt(Copy(s, i, 3)));
          Inc(i, 2);
        end
      {$IfDef Unicode}
        else if (c = 'u') and (i+3 < ii) then
        begin
          result[j] := fun.char(StrToInt('x' + Copy(s, i+1, 4)));
          Inc(i, 4);
        end
      {$EndIf}
        else
        begin
          result[j] := '\';
          Inc(j);
          result[j] := c;
        end;
      end
      else
        result[j] := c
      ;
      Inc(i);
      Inc(j);
    end;
    SetLength(result, j-1);
  end;

// \[btnfr"'`/\] \xHH \uHHHH
procedure _escape(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := esc(exp.asStr);
end;

// String:
//  %s
// Number:
//  ###...
// DateTime:
//  yyyy-mm-dd hh:nn:ss:zzz
procedure _format(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  ii, i: fun.int;
  vs: array of TVarRec;
  strs: array of fun.str;
begin
  with PData(exp.value)^ do
  case VType of
    VarDate: val^ := FormatDateTime(CExps.FindAsVal(exps, '', 0, ''), VDate);

    else if VType in [varSmallint..varCurrency, varShortInt..varInt64] then
      val^ := FormatFloat(CExps.FindAsVal(exps, '', 0, ''), exp.value^)
    else
    begin
      ii := CExps.Count(exps);
      SetLength(vs, ii);
      {$IfDef FPC}
      // Keep the argument strings alive (and refcounted) while Format runs.
      // Storing fun.ptr(asStr) of an inline temporary leaves a dangling
      // pointer because the temporary is released immediately.
      SetLength(strs, ii);
      {$EndIf}
      for i := 0 to ii -1 do
      begin
      {$IfDef FPC}
        {$IfDef Unicode}
        strs[i]       := CExp(exps.Item[i]).asStr;
        vs[i].VWideString := fun.ptr(strs[i]);
        vs[i].VType       := vtWideString;
        {$Else}
        strs[i]       := CExp(exps.Item[i]).asStr;
        vs[i].VAnsiString := fun.ptr(strs[i]);
        vs[i].VType       := vtAnsiString;
        {$EndIf}
      {$Else}
        vs[i].VVariant := fun.ptr(CExp(exps.Item[i]).value);
        vs[i].VType    := vtVariant;
      {$EndIf}
      end;
      val^ := Format(exp.asStr, vs);
    end;
  end;
end;

// $id
// $@@ - last error
procedure _eval(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  s, v: fun.str;
  i, j, ii, siz: fun.int;
  c: fun.char;
  e: CExp;
const
  k4 = 4096;
label
  rep;
begin
  s   := exp.asStr;
  ii  := Length(s);
  siz := ((ii div k4) + 1) * k4;
  SetLength(s, siz);
  i  := 1;
  while i <= ii do
  begin
    c := s[i];
    Inc(i);
    if c = '$' then
    begin
      for j := i to ii+1 do
      begin
        if (j > ii) or (not (s[j] in ['_', '@'..'Z', 'a'..'z', '0'..'9'])) then
        begin
          v := Copy(s, i, j-i);
          e := exp.UID(v);
          if e <> nil then
          begin
            v := e.asStr;
      rep:  Delete(s, i-1, j-i+1);
            Inc(ii, Length(v) - (j-i+1));
            if ii > siz then
            begin
              siz := ((ii div k4) + 1) * k4;
              SetLength(s, siz);
            end;
            Insert(v, s, i-1);
            Inc(i,  Length(v) - 1);
          end
          else if v = '@@' then
          begin
            v := env.lastErrorFun();
            goto rep;
          end;
          break;
        end;
      end;
    end;
  end;
  SetLength(s, ii);
  val^ := s;
end;

//==============================================================
// 0.time(), a.time(), qpf/qpc: -1/-2.time(), file/dir.time(params, set)
procedure _time(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  i: fun.int;
  e: CExp;
  t: fun.time;
  i64: fun.int64;
  {$IfDef Linux}
  ts: timespec;
  {$EndIf}
begin
  if isNum(exp.value) then
  begin
    i := exp.asInt;
    if i = 0 then
      val^ := Time
    else if (i >= 2010) and (i < 2100) then
      val^ := 20260602 // todo: runtime version
    else if i < 0 then
    begin
    {$IfNDef Linux}
      if i = -1 then QueryPerformanceFrequency(i64)
                else QueryPerformanceCounter  (i64);
    {$Else}
      if clock_gettime(CLOCK_MONOTONIC, @ts) = 0 then
      begin
        // qpf (-1): ticks per second; qpc (-2): current monotonic counter.
        // CLOCK_MONOTONIC resolution is 1 ns, so count = ns and freq = 1e9/s.
        if i = -1 then i64 := 1000000000
                  else i64 := int64(ts.tv_sec) * 1000000000 + ts.tv_nsec;
      end
      else i64 := 0;
    {$EndIf}
      val^ := i64;
    end
    else
      val^ := Now;
    ;
  end
  else begin
    e := CExps.Find(exps, 'set', 1);
    if e <> nil then
      t := e.value^
    else
      t := 0
    ;

    val^ := CIO.Time(exp.asStr, CExps.FindAsVal(exps, '', 0, 0), t)
  end;
end;

procedure _size(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := CIO.Time(exp.asStr, 8);
  PData(val).VType := VarLongWord;
end;

//==============================================================
// 0-MD5, 1-SHA1
procedure _hash(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  val^ := CIO.Load(exp.asStr, 0, CExps.FindAsVal(exps, '', 0, 0));
end;

// s.load(cp = 0)
procedure _load(env: CEnv; exp: CExp; exps: CExps; val: PValue);
{$IfNDef Unicode}
begin
  val^ := NullValue;
  val^ := CIO.Load(exp.asStr, CExps.FindAsVal(exps, 'cp', 0, 0));
{$Else}
var
  e : CExp;
  cp: fun.word;
begin
  cp := 0;
  e  := CExps.Find(exps, 'cp', 0);
  if e <> nil then cp := fun.word(e.asInt);
  val^ := NullValue;
  val^ := CIO.Load(exp.asStr, cp);
  if (e <> nil) and (e is CVar) then e.value^ := CP_Last;
{$EndIf}
end;

// f.save(str, cp = 0, append = false)
// cp 10056 - utf8 without bom
procedure _save(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  s: fun.str;
  e: CExp;
begin
  {$IfDef CompSave}
  e := CExps.Find(exps, '', 0);
  if (e <> nil) and (e.asObj is CNode) then
  begin
    s := '';
    CCSaver.SaveFoo(e.asObj, s);
  end
  else
  {$EndIf}
  s := CExps.FindAsVal(exps, '', 0, '');
  CIO.Save(exp.asStr, s, CExps.FindAsVal(exps, 'cp', 1, 0), CExps.FindAsVal(exps, 'append', 2, false));
end;

// f.find(sub = false, size = false, rel = false)
// f -> file default
// f -> directory if endswith '\'
// Callback for CIO.Find: append each hit to the CNew collection passed as tag.
// Kept as a module-level (non-nested) procedure: a nested routine has a hidden
// frame pointer and cannot be called through CIO.Find's plain CFindEach proc
// pointer on FPC (it would misalign its args and crash).
procedure _find_collect(const f: fun.str; p: fun.ptr; size: fun.int = -1);
var
  fs: CNew;
  e: CExp;
begin
  fs := CNew(p);
  e := CExp.new(nil);
  if size >= 0 then
  begin
    e.name := f;
    e.parse(size);
  end
  else e.parse(f);
  fs.items.add(e);
end;

procedure _find(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  fs: CNew;
begin
  fs := CNew(core.CNew.new(nil).parse(CExps.Create()));
  setObj(val, fs, VarObjNew); del(fs);
  CIO.Find(exp.asStr, CExps.FindAsVal(exps, 'sub', 0, false), CExps.FindAsVal(exps, 'size', 1, false), CExps.FindAsVal(exps, 'rel', 2, false), @_find_collect, fs);
end;

// f.copy(f2, f3, ...)
procedure _copy(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  s: fun.str;
  i: fun.int;
begin
  s := exp.asStr;
  for i := 0 to CExps.Count(exps) -1 do
    CIO.Copy(s, CExp(exps.Item[i]).asStr)
  ;
end;

// f.move(f2), delete f if f2 = null
// s.move(intDest)
// i.move(intDest, intLen) ???
procedure _move(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  e: CExp;
  s: string;
  p, q: fun.ptr;
  i: fun.int;
begin
  s := exp.asStr;
  e := CExps.Find(exps, 'dest', 0);
  if (e <> nil) and isNum(e.value) then
  begin
    p := fun.ptr(e.asInt);
    q := @s[1];
    i := CExps.FindAsVal(exps, 'len', 1, 0);
    if i = 0 then i := Length(s);
    if isNum(PData(exp.value)^.VType) then q := fun.ptr(exp.asInt);
    Move(q^, p^, i * sizeof(char));
  end else
    CIO.Move(s, CExps.FindAsVal(exps, '', 0, ''))
  ;
end;

// s.movs(dest, len, pos, pod)
procedure _movs(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  ed: CExp;
  s, d: fun.str;
  pos, pod, len, ls, ld: fun.int;
  ps, pd: fun.ptr;
begin
  s  := exp.asStr;
  if not isStr(exp.value) or (s = '') then exit;
  ed := CExps.Find(exps, 'dest', 0);
  if ed = nil then exit;
  d  := fun.str(fun.ptr(PData(ed.value).VInteger));
  if not isStr(ed.value) or (d = '') then exit;

  ls  := Length(s);
  ld  := Length(d);
  len := calcIndex(CExps.FindAsVal(exps, 'len', 1, 0), ls);
  pos := calcIndex(CExps.FindAsVal(exps, 'pos', 2, 0), ls);
  pod := calcIndex(CExps.FindAsVal(exps, 'pod', 3, 0), ld);
  if len = 0 then len := ls - pos;
  
  if (pos < 0) or (pos + len > ls) or (pod < 0) or (pod + len > ld) then
    raise EBase.Create('out of bounds');

  ps := @s[1 + pos];
  pd := fun.ptr(PData(ed.value).VInteger + pod);
  Move(ps^, pd^, len * sizeOf(char));
  val^ := len;
end;

//==============================================================
// index: 0, -2: UnicodeString
procedure _toStr(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  i: fun.int;
  s: fun.str;
  v: PVarArray;
  p: fun.ptr;
  {$IfDef Unicode}
  a: AnsiString;
  j: fun.int;
  {$Else}
  o: WideString;
  {$EndIf}
begin
  i := CExps.FindAsVal(exps, 'index', 0, 0);
  with PData(exp.value)^ do
    if VType = VarArray+VarVariant then
      val^ := exp.value^[i] // Array of Variant
    else if VType = VarArray+VarByte then
    begin
      v := PData(exp.value).VArray;
      i := v.Bounds[0].ElementCount;
      SetLength(s, i);
    {$IfDef Unicode}
      SetLength(a, i);
      p := @a[1];
      System.Move(v.Data^, p^, i);
      for j := 1 to i do s[j] := fun.char(a[j]);
    {$Else}
      p := @s[1];
      System.Move(v.Data^, p^, i);
    {$EndIf}
      val^ := s;
    end
    {$IfNDef Unicode}
    else if i = -2 then
    begin
      s := exp.asStr;
      SetLength(o, Length(s));
      for i := 1 to Length(s) do o[i] := WideChar(s[i]);
      val^ := o;
    end
    {$EndIf}
    else
      val^ := exp.asStr
    ;
end;

// ptr:  1-intPtr, 2-floatPtr, 3-doublePtr,
// ptr: -1:ptr
procedure _toNum(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  p: fun.int;
  s: fun.str;
  i: ^fun.uint;
  f: ^Single;
  d: ^fun.real;
begin
  //val^ := exp.value^ * 1;
  p := CExps.FindAsVal(exps, 'ptr', 0, 0);
  if p = 0 then
    val^ := CParser.StrToNum(exp.value^)
  else
  begin
    s := exp.asStr();
    if p = -1 then
      val^ := PData(exp.value).VInteger
    else if p = 1 then
    begin
      i := @s[1];
      val^ := i^;
    end
    else if p = 2 then
    begin
      f := @s[1];
      val^ := f^;
    end
    else if p = 3 then
    begin
      d := @s[1];
      val^ := d^;
    end;
  end;
end;

procedure _toTime(env: CEnv; exp: CExp; exps: CExps; val: PValue);
begin
  // todo
  val^ := ToFunTime(exp.asStr);
end;

// s.toByte(pos = 0)
procedure _toByte(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  s: fun.str;
  c: fun.char;
begin
  s := exp.asStr;
  if s = '' then
    c := #0
  else
    c := s[1 + CExps.FindAsVal(exps, 'pos', 0, 0)]
  ;
  val^ := fun.int(c);
end;

// s.fromByte(pos, byte)
procedure _fromByte(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  i, j: fun.int;
  s: fun.str;
  p: PByte;
begin
  i := CExps.FindAsVal(exps, 'pos',  0, 0);
  j := CExps.FindAsVal(exps, 'byte', 1, 0);
  s := exp.asStr;
  p := fun.ptr(s);
  Inc(p, i);
  p^ := j;
end;

procedure _toChar(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  s: fun.str;
begin
  s    := #0;
  s[1] := fun.char(fun.uint(exp.value^) mod 65536);
  val^ := s;
end;

//==============================================================
// s.toRegex(= ''), options
procedure _toRegex(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  e: CExp;
begin
  {$IfDef Regex}
  e := CRegex.new(nil).parse(exp.asStr, CExps.FindAsVal(exps, '', 0, ''));
  setObj(val, e, VarObjNew); del(e);
  {$EndIf}
end;

//==============================================================
// x.match(y, action = nil)
procedure _match(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  e: CExp;
begin
  e := CExps.Find(exps, '', 0);
  if e = nil then
    val^ := NullValue
  else
  begin
    if e.asObj = nil then
      val^ := Pos(e.asStr, exp.asStr) > 0
    else
      {$IfDef Regex}
      CRegex(e.asObj).match(env, exp.asStr, CExps.Find(exps, 'action', 1), val)
      {$EndIf}
    ;
  end;
end;

procedure _replace(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  e, e2: CExp;
begin
  e  := CExps.Find(exps, '', 0);
  e2 := CExps.Find(exps, '', 1);
  if e = nil then
    val^ := NullValue
  else
  begin
    if e.asObj = nil then
      val^ := NewStringReplace(exp.asStr, e.asStr, e2.asStr, [rfReplaceAll, rfIgnoreCase])
      //val^ := NewStringReplace(exp.asStr, e.asStr, e2.asStr, [rfReplaceAll])
    else
      {$IfDef Regex}
      CRegex(e.asObj).replace(env, exp.asStr, e2, val)
      {$EndIf}
    ;
  end;
end;

//==============================================================
// s.compile(inline = false)
procedure _compile(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  s, fn: fun.str;
  b: fun.bool;
  n: CNode;
begin
  s := exp.asStr;
  n := env.lastNode.root;
  if Length(s) < 256 then // Length of FileName
    fn := _ParserClass.ParseFileName(s, n)
  ;
  b := CExps.FindAsVal(exps, 'inline', 0, false);
  {if not b then} n := nil;
  if FileExists(fn) then
    n  := CParser.ParseOrLoad(fn, n, _ParserClass)
  else
    n  := CParser.Parse(s, _ParserClass, '', n)
  ;
  if b then n.parent := env.lastNode;
  setObj(val, n, VarObjNew); del(n);
end;

//==============================================================
function SseDecompress(const Input: fun.str): fun.str;
var
  i, L, num, j, lineStart: fun.int;
  o, line: fun.str;
begin
  Result := '';
  o := '';
  i := 1;
  L := Length(Input);
  while i <= L do
  begin
    lineStart := i;
    while (i <= L) and not (Input[i] in [#10, #13]) do Inc(i);
    line := Copy(Input, lineStart, i - lineStart);

    num := 0;
    j := 1;
    while (j <= Length(line)) and (line[j] in ['0'..'9']) do Inc(j);
    if (j > 1) and (j <= Length(line)) and (line[j] = ')') then
    begin
      num := StrToInt(Copy(line, 1, j-1));
      Delete(line, 1, j);
    end;

    if num > 0 then
      o := Copy(o, 1, num) + line
    else
      o := line;

    Result := Result + o;
    while (i <= L) and (Input[i] in [#10, #13]) do
    begin
      Result := Result + Input[i];
      Inc(i);
    end;
  end;
end;

//==============================================================
function _ParseJson(const s: fun.str; json: fun.bool = false; fd: fun.bool = false; sse: fun.bool = false): CNode;
var
  Root: CSet;
  Level: fun.int;
  Stack: array of fun.ptr;

  function Peek(): CExps;
  begin
    Result := Stack[Level -1];
  end;

  procedure Push(const name: fun.str; isObj: fun.bool = false); forward;
  procedure GetVal(const name: fun.str; vv: PData);
  var
    e: CExp;
  begin
    if (Level = 0) and (Length(Stack) = 0) then Push('');
    e := CExp.new(nil);
    e.name := name;
    e.assign(PValue(vv));
    Peek.Add(e);
  end;

  procedure Push(const name: fun.str; isObj: fun.bool = false);
  var
    n: CSet;
    v: CData;
  begin
    // Empty the Data
    v.VType := VarEmpty;

    if isObj then
      n := CNew2.new(nil)
    else
      n := CNew.new(nil)
    ;
    n.parse(CExps.create);
    if Level = 0 then
      Root := n
    else
    begin
      setObj(PValue(@v), n, VarObjNew); del(n);
      GetVal(name, @v);                 del(n);
    end;
    Inc(Level);
    SetLength(Stack, Level);
    Stack[Level -1] := n.items;
  end;

  procedure Pop();
  begin
    if Level > 1 then Dec(Level);
  end;

  procedure ParseJSON;
  var
    i, ii, oi, bs: fun.int;
    c: fun.char;
    kv, k, kk: fun.str;
    vv: CData;
  label
    _STR, _NUM, _KEY;
  begin
    ii := Length(s);
    i  := 1;
    while i <= ii do
    begin
      c  := s[i];
      oi := i;
      case c of
        '"', '''', '`':
  _STR: begin
          bs := 0;
          repeat
            if s[i] = '\' then Inc(bs)
                          else bs := 0;
            Inc(i);
          until (i >= ii) or (s[i] = c) and ((bs mod 2 = 0) or not json);
          if i = ii then
            kv := Copy(s, oi + 1, i - oi)
          else
            kv := Copy(s, oi + 1, i - oi - 1)
          ;
          if s[oi-1] = '@' then
            CValue(vv) := StrToDateTime(kv)
          else if json then
          begin
            kv := esc(kv);
            CValue(vv) := kv;
          end
          else
            CValue(vv) := kv
          ;
          kk := c;
        end;

        '0':
        begin
          if s[i+1] in ['x', 'X'] then
          begin
            Inc(i, 2);
            repeat
              Inc(i);
            until not (s[i] in ['0'..'9', 'A'..'F', 'a'..'f']) or (i >= ii);
            kv := Copy(s, oi, i - oi);
            CValue(vv) := CParser.StrToNum(kv);
            Continue;
          end
          else goto _NUM;
        end;

        '1'..'9', '-', '.':
  _NUM: begin
          repeat
            Inc(i);
          until not (s[i] in ['0'..'9', '.', 'e', 'E', '-', '+']) or (i >= ii);
          kv := Copy(s, oi, i - oi);
          CValue(vv) := CParser.StrToNum(kv);
          Continue;
        end;

        '@':
        begin
          if s[i+1] in ['"', '''', '`'] then
          begin
            Inc(i);
            Continue;
          end
          else goto _KEY;
        end;

        '$', '_', 'A'..'Z', 'a'..'z':
  _KEY: begin
          repeat
            Inc(i);
          until not (s[i] in ['$', '_', '@'..'Z', 'a'..'z', '0'..'9']) or (i >= ii);
          kv := Copy(s, oi, i - oi);
          if (kv = 'null') or (kv = 'nil') then
            CValue(vv) := NullValue
          else if kv = 'true' then
            CValue(vv) := true
          else if kv = 'false' then
            CValue(vv) := false
          else
            CValue(vv) := kv;
          Continue;
        end;

        ':', '=':
          k  := kv;

        ',', ';':
        begin
          if k + kv + kk <> '' then GetVal(k, @vv);
          k  := '';
          kv := '';
          kk := '';
        end;

        '[', '{':
        begin
          Push(k, c = '{');
          k  := '';
          kv := '';
          kk := '';
        end;

        ']', '}':
        begin
          if k + kv + kk <> '' then GetVal(k, @vv);
          k  := '';
          kv := '';
          kk := '';
          Pop();
        end;
      end;
      Inc(i);
    end;
  end;

  {$I 'libfd.inc'}

begin
  Root  := nil;
  Level := 0;

  if fd then
  begin
    if sse then ParseFD(SseDecompress(s))
           else ParseFD(s);
  end else
    ParseJSON
  ;

  Result := Root;
end;

// json = false, fd = false, sse = false
procedure _GetJson(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  n: CNode;
begin
  n := _ParseJson(exp.asStr, CExps.FindAsVal(exps, 'json', 0, false), CExps.FindAsVal(exps, 'fd', 1, false), CExps.FindAsVal(exps, 'sse', 2, false));
  if n = nil then n := CNew.new(nil).parse(CExps.create);
  setObj(val, n, VarObjNew); del(n);
end;

{$IfDef MD5}
//{$I 'libmd5.inc'}
procedure _md5(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  i: fun.int;
  s: fun.str;
begin
  s := exp.asStr;
  i := Length(s);
  val^ := MD5(fun.ptr({$IfDef Unicode}ToRawString{$EndIf}(s))^, i);
end;

procedure _sha1(env: CEnv; exp: CExp; exps: CExps; val: PValue);
var
  i: fun.int;
  s: fun.str;
begin
  s := exp.asStr;
  i := Length(s);
  val^ := SHA(fun.ptr({$IfDef Unicode}ToRawString{$EndIf}(s))^, i);
end;
{$EndIf}

//==============================================================
constructor CLbase.Create;
begin
  inherited Create;
  // Easter egg
  ids['@uthor']  := CExp.new(nil).parse(fun.uint(@_author));
  
  // Arg or param
  ids['arg']     := CExp.new(nil).parse(fun.uint(@_arg));
  ids['set']     := CExp.new(nil).parse(fun.uint(@_set));
  
  // Math
  ids['exp']     := CExp.new(nil).parse(fun.uint(@_exp));
  ids['log']     := CExp.new(nil).parse(fun.uint(@_log));
  ids['sin']     := CExp.new(nil).parse(fun.uint(@_sin));
  ids['cos']     := CExp.new(nil).parse(fun.uint(@_cos));
  ids['atan']    := CExp.new(nil).parse(fun.uint(@_atan));
  ids['random']  := CExp.new(nil).parse(fun.uint(@_random));
  
  // String
  ids['length']  := CExp.new(nil).parse(fun.uint(@_length));
  ids['lower']   := CExp.new(nil).parse(fun.uint(@_lower));
  ids['upper']   := CExp.new(nil).parse(fun.uint(@_upper));
  ids['subpos']  := CExp.new(nil).parse(fun.uint(@_subpos));
  ids['substr']  := CExp.new(nil).parse(fun.uint(@_substr));
  ids['x']       := CExp.new(nil).parse(fun.uint(@_x));
  ids['movs']    := CExp.new(nil).parse(fun.uint(@_movs));
  ids['escape']  := CExp.new(nil).parse(fun.uint(@_escape));
  ids['format']  := CExp.new(nil).parse(fun.uint(@_format));
  ids['eval']    := CExp.new(nil).parse(fun.uint(@_eval));
  
  // Time
  ids['time']    := CExp.new(nil).parse(fun.uint(@_time));
  
  // File
  ids['hash']    := CExp.new(nil).parse(fun.uint(@_hash));
  ids['load']    := CExp.new(nil).parse(fun.uint(@_load));
  ids['save']    := CExp.new(nil).parse(fun.uint(@_save));
  ids['find']    := CExp.new(nil).parse(fun.uint(@_find));
  ids['copy']    := CExp.new(nil).parse(fun.uint(@_copy));
  ids['move']    := CExp.new(nil).parse(fun.uint(@_move));
  ids['size']    := CExp.new(nil).parse(fun.uint(@_size));
  
  // Path
  // in env
  
  // Set/List
  // not in libase
  // @count(), @each(), @add(), @clone()
  // @toJSON()
  
  // Fun Lib
  ids['GetLib']  := CExp.new(nil).parse(fun.uint(@_getlib));
  
  // Win API
  {$IfDef WinAPI}
  // f.getapi(name, type)
  //   f    -> filename
  //   name -> method name or address
  //   type -> xxx...:x
  // getfun? getmethod?
  ids['GetApi']  := CExp.new(nil).parse(fun.uint(@_getapi));
  {$EndIf}
  
  // Linux: dlopen/dlsym via libffi (winapi unit stays Windows-only)
  {$IfDef LinuxFFI}
  ids['GetApi']  := CExp.new(nil).parse(fun.uint(@_lgetapi));
  {$EndIf}

  // Win COM
  {$IfDef WinCOM}
  // c.newobj(get = false)
  //   c -> class name or guid
  // newole? newobject?
  ids['NewObj']  := CExp.new(nil).parse(fun.uint(@_newobj));
  {$EndIf}
  
  // Type conversions
  ids['toStr']   := CExp.new(nil).parse(fun.uint(@_toStr));
  ids['toNum']   := CExp.new(nil).parse(fun.uint(@_toNum));
  ids['toTime']  := CExp.new(nil).parse(fun.uint(@_toTime));
  ids['toByte']  := CExp.new(nil).parse(fun.uint(@_toByte));
  ids['fromByte']:= CExp.new(nil).parse(fun.uint(@_fromByte));
  ids['toChar']  := CExp.new(nil).parse(fun.uint(@_toChar));
  // toRegex
  ids['toRegex'] := CExp.new(nil).parse(fun.uint(@_toRegex));
  
  // Regex
  // match
  // s.match(r) and r.match(s)
  // s =~ /../. and /../. =~ s
  //   return CMatches if 'g'
  //          CMatches is a Set/List of CMatch
  //   or
  //   return CMatch
  //          CMatch is a Obj inherited Set
  //            0: match, 1~n: groups
  //            .@next(): match next
  //            .@value(), @matched(): [0]
  //            .@missed(): un-matched
  ids['match']   := CExp.new(nil).parse(fun.uint(@_match));
  // replace
  // s.replace(r, s2) and r.replace(s, s2)
  ids['replace'] := CExp.new(nil).parse(fun.uint(@_replace));
  
  // Parse ...
  // parseAsJSON
  // parseAsFUN, parseAsScript, compile
  //   带 inline 参数
  // parseAsXML, 这个可以作为正则用 fun 来做
  // parseAsINI, 这个可以作为正则用 fun 来做
  // ...
  ids['compile'] := CExp.new(nil).parse(fun.uint(@_compile));
  ids['GetJson'] := CExp.new(nil).parse(fun.uint(@_GetJson));
  
  {$IfDef MD5}
  ids['md5']     := CExp.new(nil).parse(fun.uint(@_md5));
  ids['sha1']    := CExp.new(nil).parse(fun.uint(@_sha1));
  {$EndIf}
end;

function CLbase.accept(exp: CExp): fun.bool;
begin
  result := exp.asObj = nil;
end;


end.
