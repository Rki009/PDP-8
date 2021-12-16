@Rem  Use Ubuntu palbart to assemble for PDP-8
@Rem - build balbart from sources or install on linux

set "PROJ=gps_clock"

:again
color 1f
cls
set "TOOLS=..\..\Tools\bin"
set "PALBART=%TOOLS%\palbart-2.14.exe"

@Rem %PALBART% -v
@Rem %PALBART% -h

%PALBART% -t 4 -$ -d %PROJ%.pal
@if errorlevel 1 goto oops

%TOOLS%\tape2mem.exe %PROJ%.bin %PROJ%.mem
%TOOLS%\tape2mif.exe %PROJ%.bin %PROJ%.mif

@pause
@goto done


@echo All ok!
@pause
@goto again

:oops
@echo "****  OOPS  ****"
@pause
@goto again

:done
exit
