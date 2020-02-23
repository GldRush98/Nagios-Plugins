@echo OFF
SETLOCAL
REM Original code from nagios exchange (https://exchange.nagios.org/directory/Plugins/Operating-Systems/Windows/NRPE/ping_remote-2Ebat-%28-with-check_nrpe-and-nsclient%29/details)
REM Code updates by Nick Overstreet (https://www.nickoverstreet.com/)
REM Last modified: 2/23/2020

REM ensure all required info is present
IF "%1"=="" goto Usage
IF "%2"=="" goto Usage
IF "%3"=="" goto Usage
IF "%4"=="" goto Usage
IF "%5"=="" goto Usage
IF "%6"=="" goto Usage

echo %4 |find "%%%"
IF not ERRORLEVEL 1 goto Usage
echo %6 |find "%%%"
IF not ERRORLEVEL 1 goto Usage

REM assign each to a variable to reference it later
SET ip=%1
SET pkt=%2
SET wrta=%3
SET wpl=%4
SET crta=%5
SET cpl=%6

REM capture fresh data to a temp file
SET randomfilename=%RANDOM%-%1-TMP
echo ->%randomfilename%

ping %ip% -n %pkt% >>%randomfilename%

REM pick out the data we need from the temp file
FOR /F "tokens=11 delims= " %%k in ('findstr /c:"Lost" %randomfilename%') do set LST=%%k

IF ERRORLEVEL 1 GOTO timeout
FOR /F "tokens=9 delims= " %%k in ('findstr /c:"Average" %randomfilename%') do set AVG=%%k

REM trim the variables
set AVG=%AVG:m=%
set AVG=%AVG:s=%

:timeout
set LST=%LST:(=%
set LST=%LST:~0,-1%

REM special handlers for complete loss modes or ttl expiration
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

REM Compare the Warning and Critical values, and set the exit code and finish up
REM echo Debug: %LST% %AVG% %cpl% %crta% %wpl% %wrta%

if %LST% GEQ %cpl% goto CPL
if %AVG% GEQ %crta% goto Crta
if %LST% GEQ %wpl% goto WPL
if %AVG% GEQ %wrta% goto Wrta

echo OK: Loss=%LST%%%, Avrg=%AVG%ms^|rta=%AVG%ms;%wrta%;%crta% pl=%LST%%%
set exit=0
goto Finish

:CPL
echo CRITICAL: Loss=%LST%%%^|rta=%crta%;%wrta% pl=%LST%%%
set exit=2
goto Finish

:Crta
echo CRITICAL: Loss=%LST%%%, Avrg=%AVG%ms^|rta=%AVG%ms;%wrta%;%crta% pl=%LST%%%
set exit=2
goto Finish

:WPL
echo WARNING: Loss=%LST%%%, Avrg=%AVG%ms^|rta=%wrta%;%crta% pl=%LST%%%
set exit=1
goto Finish

:Wrta
echo WARNING: Loss=%LST%%%, Avrg=%AVG%ms^|rta=%AVG%ms;%wrta%;%crta% pl=%LST%%%
set exit=1
goto Finish

:Usage
echo Usage:ping_remote ^<host_address^> ^<Packets^>^<wrta^>,^<wpl^> ^<crta^>,^<cpl^>
echo example: ./check_nrpe -H 172.19.48.139 -c ping_remote -t 90 -a 172.19.88.30 65 450,1 700,5 (run from Nagios)
echo        : ping_remote 192.168.0.1 5 200,1 400,10 (run from Windows)
echo        : (wpl\cpl are in percent, without the "%%%" sign)
set exit=3

:Finish
REM Comment this exit out if you're testing at a command line and want to see the output.
exit %exit%