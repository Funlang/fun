set fpc=D:\FPC\2.4.0
set dcc=%fpc%\bin\i386-win32\ppcrossarm.exe
%dcc% funcmd.dpr -B -Sd -O2 -Ooregvar -Xs -Twince -dWinCE -dARM -d_B_ -d_C_ -dFunUIx -dWinAPIx -dWinCOMx -dRegexx -dCompiler -dCompLoad -Fu..\..\3rd;%fpc%\units\arm-wince %*