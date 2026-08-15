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
unit utils;

interface

uses fun;

procedure InitTick;
function GetTick: fun.uint;

function FindParam(const id: fun.str; idx: fun.int = 0): fun.str;
function FindParamAsBool(const id: fun.str; idx: fun.int = 0): fun.bool;

function FindCmdLine: fun.bool;
procedure FreeCmdLine;
function SetStdOut(const fn: fun.str): fun.int;

implementation

uses SysUtils
     {$IfNDef Linux}, Windows{$EndIf}
     , io
     ;

//==============================================================
var
  tick: fun.uint;

function GetTickCount: fun.uint;
begin
{$IfNDef Linux}
  result := Windows.GetTickCount;
{$Else}
  result := 0;
{$EndIf}
end;

procedure InitTick;
begin
  tick := GetTickCount;  
end;

function GetTick: fun.uint;
var
  i: fun.uint;
begin
  i      := GetTickCount;
  result := i - tick;
  tick   := i;
end;

//==============================================================
function FindParamById(const id: fun.str): fun.str;
var
  i, ii, j, l, len: fun.int;
  s: fun.str;
begin
  result := '';
  if id = '' then exit;
  
  ii := ParamCount;
  for i := 1 to ii do
  begin
    s := ParamStr(i);
    if s[1] in ['-', '/'] then
    begin
      j := Pos(id, s);
      if j = 2 then
      begin
        l   := Length(id);
        len := Length(s);
        Inc(j, l);
        if (len > j) and (s[j] in [':', '=']) then Inc(j);
        s := Copy(s, j, len - j + l);
        if s = '' then s := 'true';
        result := s;
        exit; 
      end;      
    end;
  end;
end;

function FindParam(const id: fun.str; idx: fun.int): fun.str;
var
  i, ii: fun.int;
begin
  result := FindParamById(id);
  if (result = '') and (idx > 0) then
  begin
    ii := ParamCount;
    for i := idx to ii do
    begin
      result := ParamStr(i);
      if not (result[1] in ['-', '/']) then exit;
    end;
    result := '';
  end;
end;

function FindParamAsBool(const id: fun.str; idx: fun.int): fun.bool;
begin
  result := StrToBoolDef(FindParam(id, idx), false);
end;

//==============================================================
{$IfNDef Linux}
{$IfNDef WinCE}
//function AttachConsole(dwProcessId: fun.int): fun.int; stdcall;
//         external kernel32 name 'AttachConsole';
type AttachConsoleProc = function (dwProcessId: fun.int): fun.int; stdcall;
var  AttachConsole: AttachConsoleProc;
{$EndIf}
{$EndIf}

function FindCmdLine: fun.bool;
begin
{$IfNDef Linux}
{$IfNDef WinCE}
  try
    AttachConsole := GetProc(LoadLib(kernel32), 'AttachConsole');
    result := AttachConsole(-1) <> 0;
  except
    result := false;
  end;
{$Else}
  result := true;
{$EndIf}
{$Else}
  result := true;
{$EndIf}
end;

procedure FreeCmdLine;
begin
{$IfNDef Linux}
{$IfNDef WinCE}
  FreeConsole;
  // Press Enter Key
  //keybd_event(13, 0, 0, 0);
{$EndIf}
{$EndIf}
end;

function SetStdOut(const fn: fun.str): fun.int;
begin
{$IfNDef Linux}
  result := FileCreate(fn);
{$IfNDef WinCE}
  SetStdHandle(STD_OUTPUT_HANDLE, result);
{$EndIf}
{$Else}
  result := 0;
{$EndIf}
end;

end.
