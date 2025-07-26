# ============================================================================
#                      Online-Versionscheck für Skript
# ============================================================================
# Beschreibung:
# Dieser Abschnitt prüft beim Start, ob eine neue Version verfügbar ist.
# Das Hauptskript wird nur gestartet, wenn keine neue Version existiert
# oder der Benutzer sich explizit dafür entscheidet, das Update abzulehnen.
# ============================================================================

# --- KONFIGURATION ---
# Die Versionsinformationen werden aus einer lokalen Datei geladen.
$script:VersionString = "0.0.0" # Standardwert, falls Datei nicht lesbar
$script:BuildString = "N/A"      # Standardwert, falls Datei nicht lesbar

try {
    # Pfad zur Versionsdatei im Unterordner "Versionscheck"
    $versionFilePath = Join-Path -Path $PSScriptRoot -ChildPath "Versionscheck\Version.txt"

    if (Test-Path -Path $versionFilePath) {
        # Lese den Inhalt, teile ihn am Trennzeichen '|' und weise die Werte zu.
        $versionData = (Get-Content -Path $versionFilePath -Raw).Split('|')
        $script:VersionString = $versionData[0].Trim()
        $script:BuildString = $versionData[1].Trim()
    } else {
        # Fehlermeldung, wenn die Datei nicht existiert.
        Write-Host "WARNUNG: Die lokale Versionsdatei konnte nicht gefunden werden unter: $versionFilePath" -ForegroundColor Yellow
        Write-Host "Fahre mit Standardwerten fort." -ForegroundColor Yellow
    }
}
catch {
    # Fängt Fehler beim Lesen oder Verarbeiten der Datei ab.
    Write-Host "FEHLER beim Lesen der lokalen Versionsdatei." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Fahre mit Standardwerten fort." -ForegroundColor Red
}

# URLs für den Versionscheck
$versionCheckUrl = "https://raw.githubusercontent.com/Tinnitus97/backup_my_windows_Updater/main/newversion.txt"
# URL zur Hauptseite des GitHub-Projekts, die bei einem Update geöffnet wird.
$projectUrl = "https://github.com/Tinnitus97/backup_my_windows"
# --- ENDE DER KONFIGURATION ---


# ============================================================================
#                  HIER BEGINNT IHR BISHERIGES SKRIPT
# ============================================================================
# Der Hauptteil Ihres Skripts wird in diese Funktion verschoben,
# damit wir steuern können, wann er ausgeführt wird.
function Start-MainScript {
    $mainScriptFile = "skript.ps1"
    # $PSScriptRoot ist eine automatische Variable, die immer den Pfad des Ordners enthaelt,
    # in dem das aktuelle Skript (update_check.ps1) ausgefuehrt wird.
    $mainScriptPath = Join-Path -Path $PSScriptRoot -ChildPath $mainScriptFile

    Write-Host "Versuche, das Hauptskript zu starten: $mainScriptPath"
    
    if (Test-Path -Path $mainScriptPath) {
        try {
            # Fuehrt die externe skript.ps1-Datei aus.
            & $mainScriptPath
        }
        catch {
            Write-Host "FEHLER: Bei der Ausführung von '$mainScriptFile' ist ein Fehler aufgetreten." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
    else {
        Write-Host "FEHLER: Die Datei '$mainScriptFile' konnte nicht im selben Ordner gefunden werden." -ForegroundColor Red
        Write-Host "Stellen Sie sicher, dass sich beide Skripte im gleichen Verzeichnis befinden."
    }
}
# ============================================================================


# Funktion zur Durchführung des Online-Checks und zur Steuerung des Ablaufs
function Invoke-UpdateCheckAndProceed {
    Write-Host "--------------------------------------------------"
    Write-Host "Aktuelle Skript-Version: $($script:VersionString) (Build: $($script:BuildString))"
    Write-Host "Prüfe auf neue Version online..." -NoNewline

    try {
        # Versucht, die Versionsnummer von der URL herunterzuladen.
        $onlineVersion = (Invoke-WebRequest -Uri $versionCheckUrl -UseBasicParsing -ErrorAction Stop).Content.Trim()

        Write-Host " Fertig."
        Write-Host "Online gefundene Version: $onlineVersion"

        # Vergleich der Versionen.
        if ([version]$onlineVersion -gt [version]$script:VersionString) {
            Write-Host ""
            Write-Host "**************************************************" -ForegroundColor Yellow
            Write-Host "Eine neue Version ($onlineVersion) ist verfügbar!" -ForegroundColor Yellow
            Write-Host "**************************************************" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Was möchten Sie tun?" -ForegroundColor Cyan
            Write-Host " [1] Update-Seite im Browser öffnen (Skript wird danach beendet)"
            Write-Host " [2] Update ablehnen und die aktuelle Version trotzdem starten"
            Write-Host " [3] Vorgang komplett abbrechen"
            Write-Host ""
            
            # Benutzer nach seiner Wahl fragen
            $choice = Read-Host "Ihre Wahl (1, 2 oder 3)"
            
            switch ($choice) {
                '1' {
                    Write-Host "Öffne die Projektseite: $projectUrl"
                    Start-Process $projectUrl
                    Write-Host "Das Skript wird beendet, damit Sie das Update durchführen können."
                }
                '2' {
                    Write-Host "Update wird ignoriert. Starte das Hauptskript..."
                    Write-Host "--------------------------------------------------"
                    Write-Host ""
                    Start-MainScript
                }
                default { # Fängt '3' und alle anderen Eingaben ab
                    Write-Host "Sie haben eine falsche Taste gedrückt, der Vorgang wird nun abgebrochen."
                    Read-Host "Drücken Sie ENTER, um das Fenster zu schließen."
                }
            }
        } else {
            Write-Host "Sie verwenden die aktuellste Version des Skripts."
            Write-Host "--------------------------------------------------"
            Write-Host ""
            Start-MainScript
        }
    }
    catch {
        # Dieser Block wird bei einem Fehler ausgeführt (z.B. keine Internetverbindung).
        Write-Host ""
        Write-Host "FEHLER: Konnte nicht online nach Updates suchen." -ForegroundColor Red
        Write-Host "Das Skript wird trotzdem normal fortgesetzt."
        Write-Host "--------------------------------------------------"
        Write-Host ""
        Start-MainScript
    }
}

# Startet den gesamten Prozess: Erst der Check, dann die Entscheidung.
Invoke-UpdateCheckAndProceed

# Kurze Pause am Ende, damit das Fenster nicht sofort schließt.
# Write-Host ""
# Read-Host "Drücken Sie ENTER, um das Fenster zu schließen."