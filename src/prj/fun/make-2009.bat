@echo off
call setenv.bat
set dcc=%DELPHI2009%\bin\dcc32
%dcc% funcmd -B -Q -GD -$D+ -D_B_;_C_;UNICODE_CTRLS %*
