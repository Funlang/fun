@echo off
call setenv.bat
set dcc=%DELPHI2006%\bin\dcc32
%dcc% funcmd -B -Q -GD -$D+ %*
