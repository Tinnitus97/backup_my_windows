@echo off
goto Get_Admin

:Beginn
set "dialog_auswahl=true"

TITLE DASI-Skript

set /p Version=<Versionscheck\Version.txt
set Version=%Version: =%

set /p Build=<Versionscheck\Build.txt
set Build=%Build: =% 

echo DASI-Skript Version %Version% von %Build%

call Versionscheck\Onlinecheck.bat

setlocal enabledelayedexpansion

TITLE DASI-Skript

echo ------------------------------------------------DASI-Skript----------------------------------------------------
echo	[1] Windows Benutzerprofil sichern			[7] Windows Benutzerprofil wiederherstellen
echo	[2] Firefox-Profil sichern				[8] Firefox-Profil wiederherstellen
echo	[3] Edge-Profil sichern					[9] Edge-Profil wiederherstellen
echo	[4] Chrome Profil sichern				[10] Chrome Profil wiederherstellen
echo	[5] Thunderbird Profil sichern				[11] Thunderbird Profil wiederherstellen
echo	[6] Liste von installierten Programmen exportieren	[12] Liste von installierten Programmen installieren
echo ------------------------------------------------DASI-Skript----------------------------------------------------

set /p "$asw=Bitte eine Auswahl treffen: "
call :check_dialog

for %%a in (%$asw%) do call :asw%%a
exit /b

:check_dialog
for %%a in (%$asw%) do (
    if %%a==1 (
        set "dialog_auswahl=Benutzerprofil_export"
        goto :waehle_dialog
    )
    for %%b in (2 3 4 5) do (
        if %%a==%%b (
            set "dialog_auswahl=Profil_export"
            goto :waehle_dialog
        )
    )
    if %%a==6 (
        set "dialog_auswahl=winget_export"
        goto :waehle_dialog
    )
    if %%a==7 (
        set "dialog_auswahl=Benutzerprofil_import"
        goto :waehle_dialog
    )
    for %%b in (8 9 10 11) do (
        if %%a==%%b (
            set "dialog_auswahl=Profil_import"
            goto :waehle_dialog
        )
    )
    if %%a==12 (
        set "dialog_auswahl=winget_import"
        goto :waehle_dialog
    )
)

:waehle_dialog
if "%dialog_auswahl%"=="Benutzerprofil_export" (
    call :Benutzerprofil_export
) else if "%dialog_auswahl%"=="Profil_export" (
    call :Profil_export
) else if "%dialog_auswahl%"=="winget_export" (
    call :winget_export
) else if "%dialog_auswahl%"=="Benutzerprofil_import" (
    call :Benutzerprofil_import
) else if "%dialog_auswahl%"=="Profil_import" (
    call :Profil_import
) else if "%dialog_auswahl%"=="winget_import" (
    call :winget_import
)
exit /b

:Benutzerprofil_export
call :select_folder "Bitte waehle das Benutzerprofil aus, das gesichert werden soll:" userDir
if "%userDir%"=="" goto :pauseAndExit
call :select_folder "Bitte waehlen Sie den Speicherort fuer das Backup aus:" destDir
if "%destDir%"=="" goto :pauseAndExit
exit /b

:Profil_export
call :select_folder "Bitte waehle den Benutzerordner aus, aus dem die Profildaten gesichert werden sollen:" userDir
if "%userDir%"=="" goto :pauseAndExit
call :select_folder "Bitte waehlen Sie den Speicherort fuer das Backup aus:" destDir
if "%destDir%"=="" goto :pauseAndExit
exit /b

:winget_export
call :select_folder "Bitte waehlen Sie den Speicherort fuer das Backup aus:" destDir
if "%destDir%"=="" goto :pauseAndExit
exit /b

:Benutzerprofil_import
call :select_folder "Bitte waehlen Sie den uebergeordneten Ordner des DASI-Verzeichnisses aus, um die Benutzerdaten wiederherzustellen:" userDir
if "%userDir%"=="" goto :pauseAndExit
call :select_folder "Bitte waehlen das Benutzerprofil aus, was mit den Daten aus dem Backup ueberschrieben werden soll:" destDir
if "%destDir%"=="" goto :pauseAndExit
exit /b

:Profil_import
call :select_folder "Bitte waehlen Sie den uebergeordneten Ordner des DASI-Verzeichnisses aus, um das Profil wiederherzustellen:" userDir
if "%userDir%"=="" goto :pauseAndExit
call :select_folder "Bitte waehlen Sie das Benutzerprofil aus, was mit den Daten aus dem Backup ueberschrieben werden soll:" destDir
if "%destDir%"=="" goto :pauseAndExit
exit /b

:winget_import
call :select_folder "Bitte waehlen Sie den Ordner aus, wo sich die Winget Importdatei befindet, die wiederhergestellt werden soll:" userDir
if "%userDir%"=="" goto :pauseAndExit
exit /b

:select_folder
set "psScript=Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.FolderBrowserDialog; $dialog.Description = '%~1'; $dialog.ShowNewFolderButton = $true; if ($dialog.ShowDialog() -eq 'OK') { $dialog.SelectedPath }"
for /f "delims=" %%I in ('powershell -command "%psScript%"') do set "%2=%%I"
if "%2%"=="" echo [FEHLER] Kein Ordner ausgewaehlt.
exit /b

:pauseAndExit
echo.
echo [INFO] Fehler bei der Eingabe. Druecken Sie eine beliebige Taste, um das Fenster zu schliessen.
pause >nul
exit

:asw1
echo.
echo ---------Die Sicherung des kompletten Benutzerprofils von ausgewaehlten Benutzer wird ausgefuehrt---------
echo.
echo %destDir% | findstr /I "%userDir%" >nul
if %errorlevel% equ 0 (
    echo [FEHLER] Das Zielverzeichnis liegt im Benutzerverzeichnis. Sicherung wird abgebrochen...
    goto :pauseAndExit 1
) else (
    echo [INFO] Das Zielverzeichnis liegt NICHT im Benutzerverzeichnis. Sicherung wird fortgesetzt...
)

robocopy "%userDir%" "%destDir%\Benutzerprofil" /MIR /ZB /SL /R:0 /W:0 /MT:4 /XJ /XA:SH /XD "%userDir%\Appdata" "%userDir%\Anwendungsdaten" "%userDir%\Application Data" "%userDir%\Cookies" "%userDir%\Links" "%userDir%\Favorites" "%userDir%\Local Settings" "%userDir%\My Documents" "%userDir%\NetHood" "%userDir%\PrintHood" "%userDir%\Recent" "%userDir%\Templates" "%userDir%\Start Menu" "%userDir%\Druckumgebung" "%userDir%\Netzwerkumgebung" "%userDir%\Recent" "%userDir%\SendTo" "%userDir%\Vorlagen" "%userDir%\Cookies" "%userDir%\Lokale Einstellungen" "%userDir%\Eigene Dateien"

if %errorlevel% lss 8 (
    echo [ERFOLG] Benutzerprofil wurde erfolgreich gesichert.
) else (
    echo [FEHLER] Fehler beim Sichern des Benutzerprofils. Fehlercode: %errorlevel%
    goto :pauseAndExit
)

echo.
echo ---------Die Sicherung des kompletten Benutzerprofils von ausgewaehlten Benutzer wurde ausgefuehrt--------
echo.
pause
exit/b

:asw2
echo.
echo ---------Die Sicherung von Firefox-Profil wird ausgefuehrt---------
echo.

if exist "%userDir%\AppData\Roaming\Mozilla\Firefox" (
    echo [INFO] Der Firefox wird nun beendet...    
    timeout /T 10 /nobreak    
    taskkill /f /im firefox.exe >NUL 2>&1    
    robocopy "%userDir%\AppData\Roaming\Mozilla\Firefox" "%destDir%\Firefox-Profil" /MIR /R:1 /W:1 /MT:4
    if %errorlevel% LSS 8 (
        echo [ERFOLG] Das Firefox-Profil wurde erfolgreich gesichert.
    ) else (
         echo [FEHLER] Fehler beim Sichern des Firefox-Profils.
    )
) else (
    echo [FEHLER] Das Firefox-Profil wurde nicht gefunden, das Skript wird beendet...
    goto :pauseAndExit
)

echo.
echo ---------Die Sicherung von Firefox-Profil wurde ausgefuehrt---------
echo.
pause
exit/b

:asw3
echo.
echo ---------Die Sicherung von Edge-Profil wird ausgefuehrt---------
echo.

if exist "%userDir%\AppData\Local\Microsoft\Edge\User Data\Default" (
    echo [INFO] Der Microsoft Edge wird nun beendet...     
    timeout /T 10 /nobreak    
    taskkill /f /im msedge.exe >NUL 2>&1    
    robocopy "%userDir%\AppData\Local\Microsoft\Edge\User Data\Default" "%destDir%\Edge-Profil" /MIR /R:1 /W:1 /MT:4
    if %errorlevel% LSS 8 (
        echo [ERFOLG] Das Edge Profil wurde erfolgreich gesichert.
    ) else (
         echo [FEHLER] Fehler beim Sichern des Edge-Profils.
    )
) else (
    echo [FEHLER] Das Edge Profil wurde nicht gefunden, das Skript wird beendet...
    goto :pauseAndExit
)

echo.
echo ---------Die Sicherung von Edge-Profil wurde ausgefuehrt---------
echo.
pause
exit/b

:asw4
echo.
echo ---------Die Sicherung von Chrome-Profil wird ausgefuehrt---------
echo.

if exist "%userDir%\AppData\Local\Google\Chrome\User Data\Default" (
    echo [INFO] Der Google Chrome wird nun beendet...
    Timeout /T 10 /nobreak     
    taskkill /f /im chrome.exe >NUL 2>&1   
    robocopy "%userDir%\AppData\Local\Google\Chrome\User Data\Default" "%destDir%\Chrome-Profil" /MIR /R:1 /W:1 /MT:4
    if %errorlevel% LSS 8 (
        echo [ERFOLG] Das Chrome Profil wurde erfolgreich gesichert.
    ) else (
         echo [FEHLER] Fehler beim Sichern des Chrome-Profils.
    )
) else (
    echo [FEHLER] Das Chrome Profil wurde nicht gefunden, das Skript wird beendet...
    goto :pauseAndExit
)

echo.
echo ---------Die Sicherung von Chrome-Profil wurde ausgefuehrt---------
echo.
pause
exit/b

:asw5
echo.
echo ---------Die Sicherung von Thunderbird-Profil wird ausgefuehrt---------
echo.

if exist "%userDir%\AppData\Roaming\Thunderbird" (
    echo [INFO] Der Thunderbird wird nun beendet...
    timeout /T 10 /nobreak 
    taskkill /f /im thunderbird.exe >NUL 2>&1
    robocopy "%userDir%\AppData\Roaming\Thunderbird" "%destDir%\Thunderbird-Profil" /MIR /R:1 /W:1 /MT:4
    if %errorlevel% LSS 8 (
        echo [ERFOLG] Das Thunderbird Profil wurde erfolgreich gesichert.
    ) else (
        echo [FEHLER] Fehler beim Sichern des Thunderbird-Profils.
    )
) else (
    echo [FEHLER] Das Thunderbird Profil wurde nicht gefunden, das Skript wird beendet...
    goto :pauseAndExit
)

echo.
echo ---------Die Sicherung von Thunderbird-Profil wurde ausgefuehrt---------
echo.
pause
exit/b

:asw6
echo.
echo ---------Eine Liste der Installierten Programme wird exportieren---------
echo.

if not exist "%destDir%\Winget" (
    mkdir "%destDir%\Winget"
)

winget export "%destDir%\Winget\Export.json"

echo.
echo ---------Eine Liste der Installierten Programme wurde exportiert---------
echo.
pause
exit/b

:asw7
echo.
echo ---------Die Wiederherstellung des kompletten Benutzerprofils wird ausgefuehrt---------
echo.

robocopy "%userDir%\Benutzerprofil" "%destDir%" /E /ZB /COPYALL /R:1 /W:1 /MT:4

if %errorlevel% LSS 8 (
    echo [ERFOLG] Das Benutzerprofil wurde erfolgreich wiederhergestellt.
) else (
    echo [FEHLER] Fehler bei der Wiederherstellung des Benutzerprofils.
)

echo.
echo ---------Die Wiederherstellung des kompletten Benutzerprofils wurde ausgefuehrt---------
echo.
pause
exit/b

:asw8
echo.
echo ---------Die Wiederherstellung von Firefox-Profil wird ausgefuehrt---------
echo.

if exist "%userDir%\Firefox-Profil" (
    echo [INFO] Der Firefox wird nun beendet...     
    timeout /T 10 /nobreak
    taskkill /f /im "firefox.exe" >NUL 2>&1
    echo [INFO] Loesche Mozilla Firefox Profilverzeichnis.
    del "%destDir%\AppData\Roaming\Mozilla\Firefox\*" /F /Q >NUL 2>&1
    for /d %%p in ("%destDir%\AppData\Roaming\Mozilla\Firefox\*") Do rd /Q /S "%%p" >NUL 2>&1

    robocopy "%userDir%\Firefox-Profil" "%destDir%\AppData\Roaming\Mozilla\Firefox" /MIR /R:1 /W:1 /MT:4
    if %errorlevel% LSS 8 (
        echo [ERFOLG] Das Firefox-Profil wurde erfolgreich wiederhergestellt.
    ) else (
        echo [FEHLER] Fehler bei der Wiederherstellung des Firefox-Profils.
    )
) else (
    echo [FEHLER] Das Firefox-Profil wurde nicht gefunden, das Skript wird beendet...
    goto :pauseAndExit
)

echo.
echo ---------Die Wiederherstellung von Firefox-Profil wurde ausgefuehrt---------
echo.
pause
exit/b

:asw9
echo.
echo ---------Die Wiederherstellung von Edge-Profil wird ausgefuehrt---------
echo.

if exist "%userDir%\Edge-Profil" (
    echo [INFO] Der Microsoft Edge wird nun beendet...    
    timeout /T 10 /nobreak
    taskkill /f /im msedge.exe >NUL 2>&1    
    echo [INFO] Loesche Microsoft Edge Profilverzeichnis.
    del "%destDir%\AppData\Local\Microsoft\Edge\User Data\Default\*" /F /Q >NUL 2>&1
    for /d %%p in ("%destDir%\AppData\Local\Microsoft\Edge\User Data\Default\*") Do rd /Q /S "%%p" >NUL 2>&1

    robocopy "%userDir%\Edge-Profil" "%destDir%\AppData\Local\Microsoft\Edge\User Data\Default" /MIR /R:1 /W:1 /MT:4
    if %errorlevel% LSS 8 (
        echo [ERFOLG] Das Edge-Profil wurde erfolgreich wiederhergestellt.
    ) else (
        echo [FEHLER] Fehler bei der Wiederherstellung des Edge-Profils.
    )
) else (
    echo [FEHLER] Das Edge-Profil wurde nicht gefunden, das Skript wird beendet...
    goto :pauseAndExit
)

echo.
echo ---------Die Wiederherstellung von Edge-Profil wurde ausgefuehrt---------
echo.
pause
exit/b

:asw10
echo.
echo ---------Die Wiederherstellung von Chrome-Profil wird ausgefuehrt---------
echo.

if exist "%userDir%\Chrome-Profil" (
    echo [INFO] Der Google Chrome wird nun beendet...    
    timeout /T 10 /nobreak
    taskkill /f /im chrome.exe >NUL 2>&1    
    echo [INFO] Loesche Google Chrome Profilverzeichnis.
    del "%destDir%\AppData\Local\Google\Chrome\User Data\Default\*" /F /Q >NUL 2>&1
    for /d %%p in ("%destDir%\AppData\Local\Google\Chrome\User Data\Default\*") Do rd /Q /S "%%p" >NUL 2>&1

    robocopy "%userDir%\Chrome-Profil" "%destDir%\AppData\Local\Google\Chrome\User Data\Default" /MIR /R:1 /W:1 /MT:4
    if %errorlevel% LSS 8 (
        echo [ERFOLG] Das Chrome-Profil wurde erfolgreich wiederhergestellt.
    ) else (
        echo [FEHLER] Fehler bei der Wiederherstellung des Chrome-Profils.
    )
) else (
    echo [FEHLER] Das Chrome-Profil wurde nicht gefunden, das Skript wird beendet...
    goto :pauseAndExit
)

echo.
echo ---------Die Wiederherstellung von Chrome-Profil wurde ausgefuehrt---------
echo.
pause
exit/b

:asw11
echo.
echo ---------Die Wiederherstellung des Thunderbird-Profils wird ausgefuehrt---------
echo.

if exist "%userDir%\Thunderbird-Profil" (
    echo [INFO] Der Thunderbird wird nun beendet...    
    timeout /T 10 /nobreak
    taskkill /f /im thunderbird.exe >NUL 2>&1    
    echo [INFO] Loesche Mozilla Thunderbird Profilverzeichnis.
    del "%destDir%\AppData\Roaming\Thunderbird\*" /F /Q >NUL 2>&1
    for /d %%p in ("%destDir%\AppData\Roaming\Thunderbird\*") Do rd /Q /S "%%p" >NUL 2>&1

    robocopy "%userDir%\Thunderbird-Profil" "%destDir%\AppData\Roaming\Thunderbird" /MIR /R:1 /W:1 /MT:4
    if %errorlevel% LSS 8 (
        echo [ERFOLG] Das Thunderbird-Profil wurde erfolgreich wiederhergestellt.
    ) else (
        echo [FEHLER] Fehler bei der Wiederherstellung des Thunderbird-Profils.
    )
) else (
    echo [FEHLER] Das Thunderbird-Profil wurde nicht gefunden, das Skript wird beendet...
    goto :pauseAndExit
)

echo.
echo ---------Die Wiederherstellung des Thunderbird-Profils wurde ausgefuehrt---------
echo.
pause
exit/b

:asw12
echo.
echo ---------Die exportierte Liste der Programme wird installiert---------
echo.

winget import "%userDir%\Winget\Export.json"

echo.
echo ---------Die exportierte Liste der Programme wurde installiertt---------
echo.
pause
exit/b

:pauseAndExit
pause
exit

:Get_Admin
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

if '%errorlevel%' NEQ '0' (
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"
goto Beginn
