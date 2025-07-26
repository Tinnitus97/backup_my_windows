@echo off
setlocal

:: ============================================================================
::  Batch-Skript zum Ausfuehren einer PowerShell-Datei als Administrator
:: ============================================================================

REM --- KONFIGURATION ---
REM Tragen Sie hier den Namen Ihrer PowerShell-Datei ein.
SET "scriptName=update_check.ps1"
REM --- ENDE DER KONFIGURATION ---


:: Baut den vollstaendigen Pfad zur PowerShell-Datei zusammen.
SET "powershellScript=%~dp0%scriptName%"


:: Pruefen, ob die angegebene PowerShell-Datei existiert.
echo Pruefe auf Existenz der Datei: "%powershellScript%"
if not exist "%powershellScript%" (
    echo.
    echo FEHLER: Die Datei "%scriptName%" konnte nicht im aktuellen Verzeichnis gefunden werden.
    echo Bitte stellen Sie sicher, dass die Batch- und die PowerShell-Datei im selben Ordner liegen und der Name exakt stimmt.
    echo.
    pause
    exit /b 1
)

echo Die Datei wurde gefunden.
echo.
echo Versuch, das Skript mit Administratorrechten zu starten...
echo.


:: Der Kernbefehl zum Starten mit Admin-Rechten.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%powershellScript%""' -Verb RunAs"


echo Der Befehl wurde abgesetzt. Das Skript wird in einem neuen Fenster ausgefuehrt.
echo.
endlocal