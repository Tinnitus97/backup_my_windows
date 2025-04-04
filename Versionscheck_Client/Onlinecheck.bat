@echo off
echo Es wird geprueft, ob eine Internetverbindung besteht:
ping -n 1 google.de >NUL 2>&1
IF ERRORLEVEL 1 goto Offline
IF ERRORLEVEL 0 goto Online
:Offline
echo Der PC ist Offline und die Suche nach Updates wird uebersprungen.
goto exit
:Online
echo Der PC ist Online und es wird nach einem Update von DASI-Skript gesucht.
curl -s -o updatecheckv2.bat https://raw.githubusercontent.com/Tinnitus97/backup_my_windows/refs/heads/main/Versionscheck_Server/updatecheckv2.bat >NUL
if exist "updatecheckv2.bat" call "updatecheckv2.bat"
if exist "updatecheckv2.bat" del "updatecheckv2.bat"
goto exit
:exit