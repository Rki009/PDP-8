
set PROJ=disasm8

:again
color 1f
cls

wsl make clean
wsl make all

bcc32x %PROJ%.cpp getopt.c -o %PROJ%.exe
@if errorlevel 1 goto oops
@del *.tds 2>nul 1>nul

copy %PROJ%.exe ..\bin

pause
goto again


:oops
@echo ***********  ERROR  ***********
pause
goto again
