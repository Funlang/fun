set fpc=D:\FPC\2.4.0
set dcc=%fpc%\bin\i386-win32\ppcrossarm.exe
%dcc% funcmd.dpr -B -Sd -O2 -Ooregvar -Xs -Tlinux -dLinux -dARM -dRegexx -Fu%fpc%\units\arm-linux %*