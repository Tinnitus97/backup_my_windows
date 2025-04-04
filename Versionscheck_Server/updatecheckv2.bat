@ Echo off
TITLE DASI-Skript Updatecheck
curl -s -o newversion.txt https://raw.githubusercontent.com/Tinnitus97/backup_my_windows/refs/heads/main/Versionscheck_Server/newversion.txt > nul
set /p Version=<Version.txt
set Version=%Version: =%%
set /p newversion=<newversion.txt
set newversion=%newversion: =%%
del newversion.txt
set /p Build=<Build.txt
set Build=%Build: =% 
if "%Version%" LSS "%newversion%" goto updateverfuegbar
if "%Version%" GEQ "%newversion%" goto keinupdateverfuegbar

:updateverfuegbar
echo Es ist ein Update fuer DASI-Skript Verfuegbar! 
echo.
echo Folgende Version wird grade ausgefuehrt %Version% von %Build%
echo Folgende Version ist Online Verfuegbar %newversion%
echo.
echo Soll das Update heruntergeladen werden? (j / n)
SET /p wahl=
if /i '%wahl%' == 'j' goto Webseite_Oeffnen
if /i '%wahl%' == 'n' goto Start_DASI-Skript
goto Start_DASI-Skript

:Webseite_Oeffnen
start microsoft-edge:https://github.com/Tinnitus97/backup_my_windows
exit

:Start_DASI-Skript
echo Das Update wurde uebersprungen!
goto Start

:keinupdateverfuegbar
echo DASI-Skript ist aktuell!
goto Start

:Start