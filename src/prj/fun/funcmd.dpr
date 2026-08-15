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

{$IfNdef FunDll}
program funcmd;
{$Else}
library funcmd;
{$EndIf}

{$IfNDef FPC}
{$IF CompilerVersion >= 21.0}
  {$WEAKLINKRTTI ON}
  {$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$IFEND}
{$EndIf}

//{$APPTYPE CONSOLE}

uses
  SysUtils,
  fun in '..\..\core\fun.pas',
  base in '..\..\core\base.pas',
  core in '..\..\core\core.pas',
  flow in '..\..\core\flow.pas',
{$IfNDef Linux}
  atom in '..\..\core\atom.pas',
{$EndIf}
  calc in '..\..\core\calc.pas',
  io in '..\..\core\io.pas',
  parse in '..\..\parse\parse.pas',
  libase in '..\..\lib\libase.pas',
  libset in '..\..\lib\libset.pas',
{$IfDef WinAPI}
  winapi in '..\..\lib\winapi.pas',
{$EndIf}
{$IfDef WinCOM}
  winole in '..\..\lib\winole.pas',
{$EndIf}
{$IfDef Regex}
  regex in '..\..\regex\regex.pas',
  pcre in '..\..\regex\pcre\pcre.pas',
  pcrd in '..\..\regex\pcre\pcrd.pas',
{$EndIf}
{$IfDef FunUI}
  ie in '..\..\lib\ui\ie.pas',
  ui in '..\..\lib\ui\ui.pas',
{$EndIf}
  host in '..\..\lib\host.pas',
  utils in '..\..\utils\utils.pas';

{$R *.res}

type
  CFunParser = class(CParser)
  public
    procedure DoError(const s: fun.str); override;
  end;

  CFunRunner = class(CEnv2)
  public
    procedure echo(const s: fun.str); override;
    function clone: CEnv; override;
  end;

// var
var
  isLog: fun.bool;

// Functions
procedure Println(const s: fun.str); stdcall;
begin
  try
    if isLog then Writeln(s);
  except
    on E: EBase do
      Writeln(E.Message);
  end;
end;

procedure Print(const s: fun.str);
begin
  try
    if isLog then Write(s);
  except
    on E: EBase do
      Writeln(E.Message);
  end;
end;

procedure PrintVer();
begin
  Println('');
  Println('Fun 9.0, Copyright (c) 2026, https://funlang.org');
  Println('Usage:');
  Println('  fun.exe [-fun:]<file.fun or .foo/.fxx> [-key:<key.ini>] [-log[:<log.txt>]] [-gui] [-v]');
  Println('');
end;

// CFunParser
procedure CFunParser.DoError(const s: fun.str);
begin
  Println(s);
end;

// CFunRunner
procedure CFunRunner.echo(const s: fun.str);
begin
  Print(s);
end;

function CFunRunner.clone: CEnv;
begin
  result := CFunRunner.create;
end;

// var
var
  r: CFunRunner;
  p: fun.ptr;
  f: fun.str;

{$IfDef FunDll}

function Run(arg: fun.int): fun.int; stdcall;
var
  v: CVar;
begin
  result := 1;
  if arg = -1 then
  begin // Free
    try
      del(p);
      del(r);
    except
      result := 0;
    end;
  end
  else if p = nil then
  begin // Compile
    if arg = 0 then // Fun script in dll
      f := GetModuleName(HInstance)
    else
    begin
      try
        f := fun.str(PChar(fun.ptr(arg)));
        if not FileExists(f) then f := OleStrToString(fun.ptr(arg));
      except
        f := OleStrToString(fun.ptr(arg));
      end;
    end;
    _ParserClass := CFunParser;
    try
      if FileExists(f) then
        p := CFunParser.ParseOrLoad(f)
      else
        p := CFunParser.Parse(f, CFunParser)
      ;
    except
      result := 0;
    end;
  end
  else
  begin // Run
    try
      v := CRuns(p).ID[_AT];
      if v = nil then v := CVar.new(CRuns(p), _AT);
      v.assign(arg);

      v := CRuns(p).ID[_AT + _AT];
      if v = nil then v := CVar.new(CRuns(p), _AT + _AT);
      v.assign(f);
    except
    end;
    if r = nil then
    begin
      r := CFunRunner.Create;
      _ENV := r;
    end;
    try
      CRun(p).run(r);
    except
      result := 0;
    end;
  end;
end;

exports Run;

{$Else}

  v, gui: fun.bool;
  log: fun.str;
  hlog: fun.int;

  {$IfDef _C_}
  key: fun.str;
  {$EndIf}

label
  _Run, _Exit, _Error;

{$EndIf}

begin
{$IfNdef FunDll}
  _ParserClass := CFunParser;

  gui   := FindParamAsBool('gui');
  v     := FindParamAsBool('v'  ) or FindParamAsBool('?');
  log   := FindParam(      'log');
  if not gui then gui := not FindCmdLine;
  isLog := not gui or (log <> '');

  hlog := 0;
  if isLog and gui then
  begin
    if log = 'true' then log := ParamStr(0) + '.log';
    hlog := SetStdOut(log);
  end;

  if v then PrintVer();

  p   := nil;
  f   := FindParam('fun', 1);
  if (f = '') or not FileExists(f) then
  begin
    try
      p := CFunParser.ParseOrLoad(ParamStr(0));
    except
    end;
    if p <> nil then goto _Run;
    
    f := ParamStr(0);
    if FileExists(ChangeFileExt(f, '.fun')) then f := ChangeFileExt(f, '.fun')
    else goto _Error;
    goto _Run;
    
_Error:
    PrintVer();
    goto _Exit;
  end;

  {$IfDef _C_}
  key := FindParam('key');
  if key <> '' then ParseKeyAlias(key);
  {$EndIf}


_Run:
  r := CFunRunner.Create;
  _ENV := r;

  try
    InitTick;
    if p = nil then p := CFunParser.ParseOrLoad(f);
    if v then
    begin
      Println('--------------------------------');
      Println('Compiled, time: ' + IntToStr(GetTick) + ' ms');
      Println('--------------------------------');
    end;
    CRun(p).run(r);
    if v then
    begin
      Println('--------------------------------');
      Println('Finished, time: ' + IntToStr(GetTick) + ' ms');
      Println('--------------------------------');
    end;
  except
    on E: EBase do
      Println(E.Message);
  end;

  try
    del(p);
    del(r);
  except
  end;

_Exit:
  try
    if isLog then
    begin
      Flush(Output);
      CIO.Close(hlog);
    end;
    if not gui then FreeCmdLine;
  except
  end;

{$EndIf}
end.
