set fpc=D:\FPC\2.4.0
set dcc=%fpc%\bin\i386-win32\ppcrossx64.exe
%dcc% funcmd.dpr -B -Sd -O2 -Ooregvar -Xs -Twin64 -dARM -dWinCE -dWin64 -d_B_ -d_C_ -dWinAPI -dWinCOMx -dRegexx