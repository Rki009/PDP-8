
set PROJ1=tape2mem
set PROJ2=tape2mif

:again
color 1f
cls

bcc32x %PROJ1%.cpp getopt.c -o %PROJ1%.exe
@if errorlevel 1 goto oops
bcc32x %PROJ2%.cpp getopt.c -o %PROJ2%.exe
@if errorlevel 1 goto oops
@del *.tds 2>nul 1>nul

copy *.exe ..\bin

pause
goto again


:oops
@echo ***********  ERROR  ***********
pause
goto again
