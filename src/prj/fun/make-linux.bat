set fpc=D:\FPC\2.4.0
set dcc=%fpc%\bin\i386-win32\ppc386
%dcc% funcmd.dpr -B -Sd -O2 -Ooregvar -Xs -Tlinux -dLinux -dRegexx -Fu%fpc%\units\i386-linux %*