@echo OFF
SETLOCAL
REM ####### ensure all required info is present --UNIX Var--######
@Echo %1%2%3%4%5%6|find "ARG"
IF NOT ERRORLEVEL 1 GOTO mseof

REM ####### ensure all required info is present --Win Var--######
IF "%1"=="" goto mseof
IF "%2"=="" goto mseof
IF "%3"=="" goto mseof
IF "%4"=="" goto mseof
IF "%5"=="" goto mseof
IF "%6"=="" goto mseof

@echo %4 |find "%%%"
IF not ERRORLEVEL 1 GOTO mseof
@echo %6 |find "%%%"
IF not ERRORLEVEL 1 GOTO mseof



REM ####### assign each to a variable to reference it later..######
SET ip=%1
SET pkt=%2
SET wrta=%3
SET wpl=%4
SET crta=%5
SET cpl=%6

REM ########  capture fresh data to a File #######
SET randomfilename=%RANDOM%-%1-TMP
@echo ->%randomfilename%

ping %ip% -n %pkt% >>%randomfilename%

REM ########  pickout the data we need from the File #######
FOR /F "tokens=11 delims= " %%k in ('findstr /c:"Lost" %randomfilename%') do set LST=%%k

IF ERRORLEVEL 1 GOTO timeout
FOR /F "tokens=9 delims= " %%k in ('findstr /c:"Average" %randomfilename%') do set AVG=%%k


REM ########  trim the variables...####
set AVG=%AVG:m=%
set AVG=%AVG:s=%

:timeout
set LST=%LST:(=%
set LST=%LST:~0,-1%

REM ########  special handlers for complete loss or ttl expiration  #######
FOR /F "tokens=3 delims= " %%k in ('findstr /c:"Destination host unreachable" %randomfilename%') do (
set LST=100
set AVG=4000
)
FOR /F "tokens=3 delims= " %%k in ('findstr /c:"Destination net unreachable" %randomfilename%') do (
set LST=100
set AVG=4000
)
FOR /F "tokens=3 delims= " %%k in ('findstr /c:"TTL expired" %randomfilename%') do (
set LST=100
set AVG=4000
)

DEL /Q %randomfilename%


REM ######## Now the fun stuff,  compare the Warning, Critical values..####
rem echo Here: %LST% %AVG% %cpl% %crta% %wpl% %wrta%

if %LST% GEQ %cpl% goto CPL-2
if %AVG% GEQ %crta% goto Crta-2
if %LST% GEQ %wpl% goto WPL-1
if %AVG% GEQ %wrta% goto Wrta-1

Goto OK-0

:CPL-2
@echo CRITICAL: Loss=%LST%%%^|rta=%crta%;%wrta% pl=%LST%%%
rem GOTO EOF
@exit 2

:Crta-2
@echo CRITICAL: Loss=%LST%%%, Avrg=%AVG%ms^|rta=%AVG%ms;%wrta%;%crta% pl=%LST%%%
rem GOTO EOF
@exit 2

:WPL-1
@echo WARNING: Loss=%LST%%%, Avrg=%AVG%ms^|rta=%wrta%;%crta% pl=%LST%%%
rem GOTO EOF
@exit 1

:Wrta-1
@echo WARNING: Loss=%LST%%%, Avrg=%AVG%ms^|rta=%AVG%ms;%wrta%;%crta% pl=%LST%%%
rem GOTO EOF
@exit 1

:OK-0
@ECHO OK: Loss=%LST%%%, Avrg=%AVG%ms^|rta=%AVG%ms;%wrta%;%crta% pl=%LST%%%
rem GOTO EOF
@Exit 0

:mseof
@echo Usage:ping_remote ^<host_address^> ^<Packets^>^<wrta^>,^<wpl^> ^<crta^>,^<cpl^>
@echo example:  /usr/local/nagios/libexec/check_nrpe -H 172.19.48.139 -c ping_remote -t 90 -a 172.19.88.30 65 450,1 700,5 (From Nagios SVR.)
@echo        : ping_remote 192.168.0.1 5 200,1 400,10 (From a local win wks where ping_remote.bat resides)
@echo        : (wpl\cpl are in percent, without the "%%%" symbol!!)

GOTO EOF
@exit 0

:eof