#Requires -Version 5.1
#Requires -RunAsAdministrator

#------------------------------------------------------------------------------------
# DASI-Skript - PowerShell Version
#------------------------------------------------------------------------------------

# --- Globale Einstellungen und Initialisierung ---
$Host.UI.RawUI.WindowTitle = "DASI-Skript"

# Lese die Version dynamisch aus der Versionsdatei.
$script:VersionString = "0.0.0" # Standardwert
$script:BuildString = "N/A"      # Standardwert
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
        Write-Warning "Die lokale Versionsdatei konnte nicht gefunden werden unter: $versionFilePath"
    }
}
catch {
    # F ngt Fehler beim Lesen oder Verarbeiten der Datei ab.
    Write-Host "FEHLER beim Lesen der lokalen Versionsdatei." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}


$script:GlobalSourceUserProfileDir = $null
$script:GlobalBackupBaseDir = $null

# --- Hilfsfunktionen ---

# Funktion zum Anzeigen eines Ordnerauswahldialogs
function Select-FolderDialog {
    param (
        [string]$Description
    )
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = $Description
        $dialog.ShowNewFolderButton = $true

        # Erstelle ein unsichtbares Besitzer-Formular (owner form)
        $form = New-Object System.Windows.Forms.Form
        $form.StartPosition = 'CenterScreen'
        $form.Size = [System.Drawing.Size]::new(0, 0)
        $form.ShowInTaskbar = $false
        $form.TopMost = $true
        $form.WindowState = 'Normal'

        $null = $form.Show()
        $null = $form.BringToFront()
        $null = $form.Focus()

        $result = $dialog.ShowDialog($form)
        $form.Dispose()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            return [string]$dialog.SelectedPath
        } else {
            return $null
        }
    }
    catch {
        Write-Warning "Fehler beim Initialisieren des Ordnerdialogs: $($_.Exception.Message)"
    }
    return $null
}

# Funktion zum Pausieren und Beenden des Skripts
function Invoke-PauseAndExit {
    param(
        [string]$Message = "[INFO] Aktion abgeschlossen oder Fehler aufgetreten."
    )
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    Write-Host "Druecken Sie eine beliebige Taste, um das Fenster zu schliessen..." -NoNewline
    if ($Host.Name -eq "ConsoleHost") {
        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    } else {
        Read-Host
    }
    exit
}

# Funktion zur Pr fung und Installation von Anwendungsupdates (Firefox/Thunderbird)
function Invoke-AppUpdateCheckAndInstall {
    param(
        [string]$AppName,
        [string]$ExeName # z.B. "firefox.exe" oder "thunderbird.exe"
    )

    Write-Host "`n--------------------------------------------------------------------------------------------------------------"
    Write-Host "[INFO] Pruefe auf Updates fuer $AppName..."

    # 1. Installierte Version aus der Registry holen
    $installedVersion = $null
    $exePath = $null
    try {
        $appPathEntry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$ExeName" -ErrorAction SilentlyContinue
        if ($appPathEntry) {
            $exePath = $appPathEntry.'(Default)'
            if (Test-Path $exePath) {
                $installedVersionString = (Get-Item $exePath).VersionInfo.ProductVersion
                # Version-String wie "115.0.3 (64-bit)" behandeln
                $installedVersion = [version]($installedVersionString.Split(' ')[0])
                Write-Host "[INFO] Installierte $AppName Version: $installedVersion"
            }
        } else {
            Write-Host "[WARNUNG] $AppName scheint nicht installiert zu sein oder wurde im Registrierungspfad nicht gefunden. Update-Pruefung wird uebersprungen."
            return # Funktion beenden, wenn nicht gefunden
        }
    } catch {
        Write-Warning "Konnte installierte Version von $AppName nicht ermitteln: $($_.Exception.Message). Update-Pruefung wird uebersprungen."
        return
    }

    # 2. Neueste Version von Mozilla abrufen
    $latestVersion = $null
    $productIdentifier = $AppName.ToLower()
    $apiUrl = "https://product-details.mozilla.org/1.0/${productIdentifier}_versions.json"
    try {
        $versionInfo = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        if ($productIdentifier -eq "firefox") {
            $latestVersionString = $versionInfo.LATEST_FIREFOX_VERSION
        } else { # thunderbird
            $latestVersionString = $versionInfo.LATEST_THUNDERBIRD_VERSION
        }
        $latestVersion = [version]$latestVersionString
        Write-Host "[INFO] Neueste verfuegbare $AppName Version: $latestVersion"
    } catch {
        Write-Warning "Konnte neueste Version von $AppName nicht von Mozilla abrufen: $($_.Exception.Message). Update-Pruefung wird uebersprungen."
        return
    }

    # 3. Vergleichen und bei Bedarf aktualisieren
    if ($latestVersion -gt $installedVersion) {
        Write-Host "[AKTION] Eine neuere Version von $AppName ($latestVersion) ist verfuegbar. Update wird durchgefuehrt." -ForegroundColor Yellow
        
        # Anwendung vor dem Update schlie en
        $processName = $ExeName.Replace(".exe", "")
        Write-Host "[INFO] Der $AppName ($processName) wird nun beendet (falls er laeuft)..."
        Get-Process $processName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3

        # 4. Herunterladen
        $downloadUrl = "https://download.mozilla.org/?product=${productIdentifier}-latest-ssl&os=win64&lang=de"
        $installerPath = Join-Path $env:TEMP "${productIdentifier}-installer.exe"
        
        try {
            Write-Host "[INFO] Lade die neueste Version von $AppName herunter..."
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            Write-Host "[ERFOLG] Download abgeschlossen." -ForegroundColor Green
        } catch {
            Write-Host "[FEHLER] Download des $AppName Installers fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
            if (Test-Path $installerPath) { Remove-Item $installerPath -Force }
            return
        }

        # 5. Stille Installation
        try {
            Write-Host "[INFO] Starte die stille Installation von $AppName. Bitte warten..."
            Start-Process -FilePath $installerPath -ArgumentList "-ms" -Wait -ErrorAction Stop
            Write-Host "[ERFOLG] $AppName wurde erfolgreich aktualisiert." -ForegroundColor Green
        } catch {
            Write-Host "[FEHLER] Die Installation von $AppName ist fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            if (Test-Path $installerPath) { Remove-Item $installerPath -Force }
        }
        
    } else {
        Write-Host "[INFO] $AppName ist bereits auf der neuesten Version." -ForegroundColor Green
    }
     Write-Host "--------------------------------------------------------------------------------------------------------------`n"
}

# Funktion, die sicherstellt, dass eine App installiert ist
function Ensure-AppIsInstalled {
    param (
        [string]$AppName,
        [string]$ExeName
    )
    
    Write-Host "`n--------------------------------------------------------------------------------------------------------------"
    Write-Host "[INFO] Pruefe, ob $AppName installiert ist..."
    
    # Pr fen, ob der App Path in der Registry existiert
    $appPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$ExeName"
    if (-not (Test-Path $appPath)) {
        Write-Host "[WARNUNG] $AppName scheint nicht installiert zu sein." -ForegroundColor Yellow
        
        # Sonderfall f r Edge
        if ($AppName -eq "Edge") {
            Write-Host "[INFO] Microsoft Edge ist eine Kernkomponente von Windows und sollte vorhanden sein. Installation wird uebersprungen."
            Write-Host "--------------------------------------------------------------------------------------------------------------`n"
            return
        }

        $confirmation = Read-Host "Soll versucht werden, $AppName jetzt zu installieren? (J/N)"
        if ($confirmation -ne 'j' -and $confirmation -ne 'J') {
            Write-Host "[INFO] Installation uebersprungen. Die Wiederherstellung des Profils koennte fehlschlagen."
            Write-Host "--------------------------------------------------------------------------------------------------------------`n"
            return # Funktion verlassen
        }

        # Winget-ID f r deutsche Versionen verwenden
        $wingetId = switch ($AppName) {
            "Firefox"     { "Mozilla.Firefox.de" }
            "Thunderbird" { "Mozilla.Thunderbird.de" }
            "Chrome"      { "Google.Chrome" }
            default       { $null }
        }

        if (-not $wingetId) {
             Write-Host "[FEHLER] Keine Winget-ID fuer '$AppName' definiert. Installation kann nicht durchgefuehrt werden." -ForegroundColor Red
             return
        }

        # Installation mit Winget
        try {
             Write-Host "[INFO] Versuche, $AppName (ID: $wingetId) mit Winget zu installieren..."
             winget install --id $wingetId -e --accept-package-agreements --accept-source-agreements
             if ($LASTEXITCODE -eq 0) {
                 Write-Host "[ERFOLG] $AppName wurde erfolgreich installiert." -ForegroundColor Green
             } else {
                 Write-Host "[FEHLER] Winget-Installation fehlgeschlagen mit Fehlercode: $LASTEXITCODE" -ForegroundColor Red
             }
        } catch {
            Write-Host "[FEHLER] Fehler bei der Ausfuehrung von Winget: $($_.Exception.Message)" -ForegroundColor Red
        }

    } else {
         # App ist bereits installiert.
         Write-Host "[INFO] $AppName ist bereits installiert. Pruefung abgeschlossen."
    }
    Write-Host "--------------------------------------------------------------------------------------------------------------`n"
}


# --- Kernfunktionen (Aktionen) ---

# 1. Windows Benutzerprofil sichern
function Backup-UserProfile {
    Write-Host "`n=============================================================================================================="
    Write-Host "                Windows Benutzerprofil sichern"
    Write-Host "=============================================================================================================="
    Write-Host ""
    
    if (-not $script:GlobalSourceUserProfileDir -or -not $script:GlobalBackupBaseDir) {
        Write-Host "[FEHLER] Globale Pfade fuer Benutzerprofil und Backup-Basisverzeichnis sind nicht gesetzt. Aktion uebersprungen." -ForegroundColor Red
        return $false
    }
    $userDir = $script:GlobalSourceUserProfileDir
    $destParentDir = $script:GlobalBackupBaseDir

    Write-Host "---------Die Sicherung des kompletten Benutzerprofils von '$userDir' wird ausgefuehrt---------" -ForegroundColor Cyan
    Write-Host "---------Ziel-Basisverzeichnis: '$destParentDir' ---------" -ForegroundColor Cyan

    # Pr fen, ob Zielpfad im Benutzerverzeichnis liegt (relevant, falls BackupBaseDir manuell in UserProfile gelegt wurde)
    try {
        $fullUserDir = (Get-Item -LiteralPath $userDir -ErrorAction Stop).FullName
        $fullDestParentDir = (Get-Item -LiteralPath $destParentDir -ErrorAction Stop).FullName
        $backupTargetDir = Join-Path $fullDestParentDir "Benutzerprofil"

        if ($backupTargetDir.StartsWith($fullUserDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "[FEHLER] Das Backup-Zielverzeichnis '$backupTargetDir' liegt im zu sichernden Benutzerverzeichnis '$fullUserDir'. Sicherung wird abgebrochen..." -ForegroundColor Red
            return $false
        } else {
            Write-Host "[INFO] Das Backup-Zielverzeichnis '$backupTargetDir' liegt NICHT im Benutzerverzeichnis. Sicherung wird fortgesetzt..."
        }
    } catch {
        Write-Host "[FEHLER] Fehler beim  berpr fen der Pfade: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }

    # Korrektur des $excludedDirs Arrays: Jedes Join-Path ist ein separates Element
    $excludedDirs = @(
        (Join-Path $userDir "AppData")
        (Join-Path $userDir "Anwendungsdaten") # German legacy name
        (Join-Path $userDir "Application Data") # English legacy name
        (Join-Path $userDir "Cookies")
        (Join-Path $userDir "Links") # Usually a junction
        (Join-Path $userDir "Favorites") # Usually a junction
        (Join-Path $userDir "Local Settings") # Legacy
        (Join-Path $userDir "My Documents") # Usually a junction
        (Join-Path $userDir "NetHood") # Usually a junction
        (Join-Path $userDir "PrintHood") # Usually a junction
        (Join-Path $userDir "Recent") # Usually a junction
        (Join-Path $userDir "Templates") # Usually a junction
        (Join-Path $userDir "Start Menu") # Usually a junction
        (Join-Path $userDir "Druckumgebung") # German for PrintHood
        (Join-Path $userDir "Netzwerkumgebung") # German for NetHood
        (Join-Path $userDir "SendTo") # Usually a junction
        (Join-Path $userDir "Vorlagen") # German for Templates
        (Join-Path $userDir "Lokale Einstellungen") # German for Local Settings
        (Join-Path $userDir "Eigene Dateien") # German for My Documents
        (Join-Path $userDir "Dropbox")
        (Join-Path $userDir "OneDrive")
        (Join-Path $userDir "HiDrive")
        (Join-Path $userDir "Google Drive")
        (Join-Path $userDir "iCloudDrive")
        (Join-Path $userDir "AppData\Local\Temp")
        (Join-Path $userDir "AppData\Local\Microsoft\Windows\INetCache")
        (Join-Path $userDir "AppData\Local\Google\Chrome\User Data\Default\Cache")
        (Join-Path $userDir "AppData\Local\Microsoft\Edge\User Data\Default\Cache")
    )

    $robocopyArgs = @(
        "`"$userDir`"",
        "`"$backupTargetDir`"",
        "/MIR", "/ZB", "/SL", "/R:0", "/W:0", "/MT:4", "/XJ", "/XA:SH", "/ETA"
    )
    foreach ($exDir in $excludedDirs) {
        if (Test-Path $exDir) {
            $robocopyArgs += "/XD", "`"$exDir`""
        }
    }
    
    Write-Host "[INFO] Starte Robocopy f r Benutzerprofil-Sicherung. Dies kann einige Zeit dauern..."
    Write-Host "Robocopy Befehl: robocopy $($robocopyArgs -join ' ')"
    & robocopy @robocopyArgs 2>&1 | Out-Host

    if ($LASTEXITCODE -lt 8) {
        Write-Host "[ERFOLG] Benutzerprofil wurde erfolgreich gesichert nach '$backupTargetDir'." -ForegroundColor Green
    } else {
        Write-Host "[FEHLER] Fehler beim Sichern des Benutzerprofils. Robocopy Fehlercode: $LASTEXITCODE" -ForegroundColor Red
        return $false
    }

    Write-Host "---------Die Sicherung des kompletten Benutzerprofils wurde ausgefuehrt---------" -ForegroundColor Cyan
    return $true
}

# 7. Windows Benutzerprofil wiederherstellen
function Restore-UserProfile {
    Write-Host "`n=============================================================================================================="
    Write-Host "                Windows Benutzerprofil wiederherstellen"
    Write-Host "=============================================================================================================="
    Write-Host ""

    if (-not $script:GlobalSourceUserProfileDir -or -not $script:GlobalBackupBaseDir) {
        Write-Host "[FEHLER] Globale Pfade fuer Benutzerprofil und Backup-Basisverzeichnis sind nicht gesetzt. Aktion uebersprungen." -ForegroundColor Red
        return $false
    }
    $destDir = $script:GlobalSourceUserProfileDir
    $backupSourceDirParent = $script:GlobalBackupBaseDir
    
    $backupSourceDir = Join-Path $backupSourceDirParent "Benutzerprofil"
    if (-not (Test-Path $backupSourceDir)) {
        Write-Host "[FEHLER] Backup-Ordner '$backupSourceDir' im globalen Backup-Verzeichnis nicht gefunden. Aktion abgebrochen." -ForegroundColor Red
        return $false 
    }

    Write-Host "---------Die Wiederherstellung des kompletten Benutzerprofils von '$backupSourceDir' nach '$destDir' wird ausgefuehrt---------" -ForegroundColor Cyan
    
    # --- MODIFIZIERT: Sicherheitsabfrage entfernt ---
    Write-Host "[WARNUNG] Diese Aktion ueberschreibt Daten im Zielverzeichnis '$destDir'." -ForegroundColor Yellow

    Write-Host "[INFO] Starte Robocopy f r Benutzerprofil-Wiederherstellung. Dies kann einige Zeit dauern..."
    $robocopyArgs = @(
        "`"$backupSourceDir`"",
        "`"$destDir`"",
        "/E", "/ZB", "/COPYALL", "/R:1", "/W:1", "/MT:4", "/ETA"
    )
    Write-Host "Robocopy Befehl: robocopy $($robocopyArgs -join ' ')"
    & robocopy @robocopyArgs 2>&1 | Out-Host

    if ($LASTEXITCODE -lt 8) {
        Write-Host "[ERFOLG] Das Benutzerprofil wurde erfolgreich wiederhergestellt nach '$destDir'." -ForegroundColor Green
    } else {
        Write-Host "[FEHLER] Fehler bei der Wiederherstellung des Benutzerprofils. Robocopy Fehlercode: $LASTEXITCODE" -ForegroundColor Red
        return $false
    }
    Write-Host "---------Die Wiederherstellung des kompletten Benutzerprofils wurde ausgefuehrt---------" -ForegroundColor Cyan
    return $true
}

# Hilfsfunktion f r Profil-Backups (Firefox, Edge, Chrome, Thunderbird)
function Backup-ApplicationProfile {
    param (
        [string]$AppName,
        [string]$ProfilePathInUserDir, 
        [string]$ProcessName
    )

    # Update-Check f r bestimmte Anwendungen
    if ($AppName -eq "Firefox") {
        Invoke-AppUpdateCheckAndInstall -AppName "Firefox" -ExeName "firefox.exe"
    }
    elseif ($AppName -eq "Thunderbird") {
        Invoke-AppUpdateCheckAndInstall -AppName "Thunderbird" -ExeName "thunderbird.exe"
    }
    
    Write-Host "`n=============================================================================================================="
    Write-Host "                $AppName-Profil sichern"
    Write-Host "=============================================================================================================="
    Write-Host ""

    if (-not $script:GlobalSourceUserProfileDir -or -not $script:GlobalBackupBaseDir) {
        Write-Host "[FEHLER] Globale Pfade fuer Benutzerprofil und Backup-Basisverzeichnis sind nicht gesetzt. Aktion uebersprungen." -ForegroundColor Red
        return $false
    }
    $userDir = $script:GlobalSourceUserProfileDir
    $destParentDir = $script:GlobalBackupBaseDir
    
    Write-Host "---------Die Sicherung von $AppName-Profil aus '$userDir' wird ausgefuehrt---------" -ForegroundColor Cyan
    Write-Host "---------Ziel-Basisverzeichnis: '$destParentDir' ---------" -ForegroundColor Cyan

    $appProfilePath = Join-Path $userDir $ProfilePathInUserDir
    
    if (Test-Path $appProfilePath) {
        Write-Host "[INFO] Der $AppName ($ProcessName) wird nun beendet (falls er laeuft)..."
        Start-Sleep -Seconds 3
        Get-Process $ProcessName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        $targetBackupDir = Join-Path $destParentDir "$AppName-Profil"
        $robocopyArgs = @(
            "`"$appProfilePath`"",
            "`"$targetBackupDir`"",
            "/MIR", "/R:1", "/W:1", "/MT:4", "/ETA" 
        )
        Write-Host "Robocopy Befehl: robocopy $($robocopyArgs -join ' ')"
        & robocopy @robocopyArgs 2>&1 | Out-Host

        if ($LASTEXITCODE -lt 8) {
            Write-Host "[ERFOLG] Das $AppName-Profil wurde erfolgreich gesichert nach '$targetBackupDir'." -ForegroundColor Green
        } else {
            Write-Host "[FEHLER] Fehler beim Sichern des $AppName-Profils. Robocopy Fehlercode: $LASTEXITCODE" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "[FEHLER] Das $AppName-Profil wurde unter '$appProfilePath' nicht gefunden." -ForegroundColor Red
        return $false
    }
    Write-Host "---------Die Sicherung von $AppName-Profil wurde ausgefuehrt---------" -ForegroundColor Cyan
    return $true
}

# Hilfsfunktion f r Profil-Wiederherstellung
function Restore-ApplicationProfile {
    param (
        [string]$AppName,
        [string]$ProfilePathInUserDir, 
        [string]$ProcessName
    )
    
    # Zuerst pr fen, ob App installiert ist; dann auf Updates pr fen
    # 1. Sicherstellen, dass die Anwendung installiert ist
    $exeName = "$ProcessName.exe"
    Ensure-AppIsInstalled -AppName $AppName -ExeName $exeName

    # 2. Update-Check f r bestimmte Anwendungen
    if ($AppName -eq "Firefox") {
        Invoke-AppUpdateCheckAndInstall -AppName "Firefox" -ExeName "firefox.exe"
    }
    elseif ($AppName -eq "Thunderbird") {
        Invoke-AppUpdateCheckAndInstall -AppName "Thunderbird" -ExeName "thunderbird.exe"
    }

    Write-Host "`n=============================================================================================================="
    Write-Host "                $AppName-Profil wiederherstellen"
    Write-Host "=============================================================================================================="
    Write-Host ""

    if (-not $script:GlobalSourceUserProfileDir -or -not $script:GlobalBackupBaseDir) {
        Write-Host "[FEHLER] Globale Pfade fuer Benutzerprofil und Backup-Basisverzeichnis sind nicht gesetzt. Aktion uebersprungen." -ForegroundColor Red
        return $false
    }
    $targetUserDir = $script:GlobalSourceUserProfileDir
    $backupParentDir = $script:GlobalBackupBaseDir

    $backupSourceDir = Join-Path $backupParentDir "$AppName-Profil"
    if (-not (Test-Path $backupSourceDir)) {
        Write-Host "[FEHLER] Das $AppName Backup-Profil '$backupSourceDir' im globalen Backup-Verzeichnis wurde nicht gefunden." -ForegroundColor Red
        return $false
    }
    
    $targetAppProfileDir = Join-Path $targetUserDir $ProfilePathInUserDir
    Write-Host "---------Die Wiederherstellung von $AppName-Profil von '$backupSourceDir' nach '$targetAppProfileDir' wird ausgefuehrt---------" -ForegroundColor Cyan

    # --- MODIFIZIERT: Sicherheitsabfrage entfernt ---
    Write-Host "[WARNUNG] Diese Aktion ueberschreibt Daten im Zielverzeichnis '$targetAppProfileDir'." -ForegroundColor Yellow
    
    Write-Host "[INFO] Der $AppName ($ProcessName) wird nun beendet (falls er laeuft)..."
    Start-Sleep -Seconds 3
    Get-Process $ProcessName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    Write-Host "[INFO] Loesche altes $AppName Profilverzeichnis (falls vorhanden): '$targetAppProfileDir'"
    if (Test-Path $targetAppProfileDir) {
        try {
            Remove-Item -Path $targetAppProfileDir -Recurse -Force -ErrorAction Stop
            Write-Host "[INFO] Altes Profilverzeichnis '$targetAppProfileDir' geloescht."
        } catch {
            Write-Warning "Konnte das alte Profilverzeichnis '$targetAppProfileDir' nicht vollstaendig loeschen: $($_.Exception.Message). Wiederherstellung koennte fehlschlagen."
        }
        Start-Sleep -Seconds 2
    }
    $parentOfTarget = Split-Path $targetAppProfileDir
    if (-not (Test-Path $parentOfTarget)) {
        New-Item -ItemType Directory -Path $parentOfTarget -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $robocopyArgs = @(
        "`"$backupSourceDir`"",
        "`"$targetAppProfileDir`"",
        "/MIR", "/R:1", "/W:1", "/MT:4", "/ETA"
    )
    Write-Host "Robocopy Befehl: robocopy $($robocopyArgs -join ' ')"
    & robocopy @robocopyArgs 2>&1 | Out-Host

    if ($LASTEXITCODE -lt 8) {
        Write-Host "[ERFOLG] Das $AppName-Profil wurde erfolgreich wiederhergestellt nach '$targetAppProfileDir'." -ForegroundColor Green
    } else {
        Write-Host "[FEHLER] Fehler bei der Wiederherstellung des $AppName-Profils. Robocopy Fehlercode: $LASTEXITCODE" -ForegroundColor Red
        return $false
    }
    Write-Host "---------Die Wiederherstellung von $AppName-Profil wurde ausgefuehrt---------" -ForegroundColor Cyan
    return $true
}

# 6. Liste von installierten Programmen exportieren (Winget)
function Export-WingetPackages {
    Write-Host "`n=============================================================================================================="
    Write-Host "                Liste von installierten Programmen exportieren"
    Write-Host "=============================================================================================================="
    Write-Host ""
    
    if (-not $script:GlobalBackupBaseDir) {
        Write-Host "[FEHLER] Globales Backup-Basisverzeichnis ist nicht gesetzt. Aktion uebersprungen." -ForegroundColor Red
        return $false
    }
    $destDir = $script:GlobalBackupBaseDir # Winget Export geht ins Backup-Basisverzeichnis

    Write-Host "---------Eine Liste der Installierten Programme wird nach '$destDir\Winget' exportiert---------" -ForegroundColor Cyan

    $wingetDir = Join-Path $destDir "Winget"
    if (-not (Test-Path $wingetDir)) {
        try {
            New-Item -ItemType Directory -Path $wingetDir -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "[FEHLER] Konnte Winget-Verzeichnis '$wingetDir' nicht erstellen: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    $exportFile = Join-Path $wingetDir "Export.json"

    try {
        Write-Host "[INFO] Exportiere Programmliste mit winget nach '$exportFile'..."
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host "[FEHLER] winget.exe nicht gefunden oder nicht im PATH. Bitte winget installieren." -ForegroundColor Red
            return $false
        }
        winget export -o "`"$exportFile`"" --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[ERFOLG] Programmliste erfolgreich nach '$exportFile' exportiert." -ForegroundColor Green
        } else {
            Write-Host "[FEHLER] Fehler beim Exportieren der Programmliste mit winget. Winget Fehlercode: $LASTEXITCODE" -ForegroundColor Red
            return $false 
        }
    } catch {
        Write-Host "[FEHLER] Winget-Befehl fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        return $false 
    }
    Write-Host "---------Eine Liste der Installierten Programme wurde exportiert---------" -ForegroundColor Cyan
    return $true
}

# 12. Liste von installierten Programmen installieren (Winget)
function Import-WingetPackages {
    Write-Host "`n=============================================================================================================="
    Write-Host "                Liste von installierten Programmen installieren"
    Write-Host "=============================================================================================================="
    Write-Host ""

    if (-not $script:GlobalBackupBaseDir) {
        Write-Host "[FEHLER] Globales Backup-Basisverzeichnis ist nicht gesetzt. Aktion uebersprungen." -ForegroundColor Red
        return $false
    }
    $importFileDir = $script:GlobalBackupBaseDir # Winget Import kommt aus dem Backup-Basisverzeichnis
    
    Write-Host "---------Die exportierte Liste der Programme aus '$importFileDir\Winget\Export.json' wird installiert---------" -ForegroundColor Cyan
    
    $importFile = Join-Path $importFileDir "Winget\Export.json"
    if (-not (Test-Path $importFile)) {
         # Fallback, falls die Datei direkt im BackupBaseDir liegt (alte Struktur)
         $importFileAlt = Join-Path $importFileDir "Export.json"
         if (Test-Path $importFileAlt) {
            $importFile = $importFileAlt
            Write-Warning "Winget Export.json in '$importFileDir\Winget' nicht gefunden, verwende '$importFileAlt'."
         } else {
            Write-Host "[FEHLER] Winget Importdatei 'Export.json' nicht im Ordner '$importFileDir\Winget' oder direkt in '$importFileDir' gefunden." -ForegroundColor Red
            return $false 
         }
    }

    try {
        Write-Host "[INFO] Importiere und installiere Programme von '$importFile' mit winget..."
        Write-Host "[WARNUNG] Dies kann einige Zeit dauern und erfordert moeglicherweise Benutzerinteraktion fuer einige Installationen." -ForegroundColor Yellow
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host "[FEHLER] winget.exe nicht gefunden oder nicht im PATH. Bitte winget installieren." -ForegroundColor Red
            return $false
        }
        winget import -i "`"$importFile`"" --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) { 
            Write-Host "[ERFOLG] Programme von '$importFile' wurden (versucht) zu installieren." -ForegroundColor Green
        } else {
            Write-Host "[WARNUNG] Winget Import beendet mit Code $LASTEXITCODE. Einige Installationen koennten fehlgeschlagen sein. Bitte Ausgabe pruefen." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[FEHLER] Winget-Befehl fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        return $false 
    }
    Write-Host "---------Die exportierte Liste der Programme wurde installiert---------" -ForegroundColor Cyan
    return $true
}


# --- Hauptmen  ---
function Show-MainMenu {
    param(
        [string]$Version,
        [string]$Build
    )
    Clear-Host
    $Host.UI.RawUI.WindowTitle = "DASI-Skript - Hauptmenue"
    Write-Host "=============================================================================================================="
    Write-Host "                                    DASI-Skript - Hauptmenue"
    Write-Host "=============================================================================================================="
    Write-Host "DASI-Skript Version $Version von $Build"
    Write-Host ""
    Write-Host "Aktuell ausgewaehltes Quell-Benutzerprofil: $($script:GlobalSourceUserProfileDir)"
    Write-Host "Aktuell ausgewaehltes Backup-Basisverzeichnis: $($script:GlobalBackupBaseDir)"
    Write-Host "--------------------------------------------------------------------------------------------------------------"
    Write-Host "   [P] Pfade neu auswaehlen (Benutzerprofil und Backup-Basisverzeichnis)"
    Write-Host "--------------------------------------------------------------------------------------------------------------"
    Write-Host "   [1] Windows Benutzerprofil sichern                  [7] Windows Benutzerprofil wiederherstellen"
    Write-Host "   [2] Firefox-Profil sichern                          [8] Firefox-Profil wiederherstellen"
    Write-Host "   [3] Edge-Profil sichern                             [9] Edge-Profil wiederherstellen"
    Write-Host "   [4] Chrome-Profil sichern                           [10] Chrome-Profil wiederherstellen"
    Write-Host "   [5] Thunderbird-Profil sichern                      [11] Thunderbird-Profil wiederherstellen"
    Write-Host "   [6] Liste von installierten Programmen exportieren  [12] Liste von installierten Programmen installieren"
    Write-Host ""
    Write-Host "   [Q] Beenden"
    Write-Host "=============================================================================================================="
    Write-Host "Geben Sie eine oder mehrere Zahlen/Buchstaben kommagetrennt ein (z.B. 1,2,6) oder 'Q' zum Beenden."
}

# Funktion zur einmaligen Auswahl der globalen Pfade
function Select-GlobalPaths {
    Write-Host "`n--- Globale Pfadauswahl ---" -ForegroundColor Green
    $tempSourceProfile = Select-FolderDialog -Description "BITTE WAEHLEN: Den Quell-Benutzerprofilordner (z.B. C:\Users\DeinName)"
    if (-not $tempSourceProfile) {
        Write-Host "[FEHLER] Kein Quell-Benutzerprofilordner ausgewaehlt. Das Skript kann nicht fortfahren." -ForegroundColor Red
        Invoke-PauseAndExit
    }
    $script:GlobalSourceUserProfileDir = $tempSourceProfile

    $tempBackupBase = Select-FolderDialog -Description "BITTE WAEHLEN: Das Hauptverzeichnis fuer alle Backups aus."
    if (-not $tempBackupBase) {
        Write-Host "[FEHLER] Kein Backup-Basisverzeichnis ausgewaehlt. Das Skript kann nicht fortfahren." -ForegroundColor Red
        Invoke-PauseAndExit
    }
    $script:GlobalBackupBaseDir = $tempBackupBase
    Write-Host "[INFO] Quell-Benutzerprofil gesetzt auf: $($script:GlobalSourceUserProfileDir)" -ForegroundColor Green
    Write-Host "[INFO] Backup-Basisverzeichnis gesetzt auf: $($script:GlobalBackupBaseDir)" -ForegroundColor Green
    Write-Host "-----------------------------------"
    Start-Sleep -Seconds 2
}


# --- Skriptablauf ---

# Globale Pfade einmalig abfragen
Select-GlobalPaths

# Hauptschleife f r Men 
do {
    Show-MainMenu -Version $script:VersionString -Build $script:BuildString
    $choicesString = Read-Host "Ihre Auswahl"
    $choicesArray = $choicesString.Trim() -split ',' | ForEach-Object {$_.Trim().ToUpper()} # Eingabe in Gro buchstaben umwandeln

    if ($choicesArray -contains "Q") {
        Write-Host "Skript wird auf Wunsch beendet."
        Start-Sleep -Seconds 2
        exit
    }
    
    if ($choicesArray -contains "P") {
        Select-GlobalPaths
        # Nach Neuauswahl der Pfade direkt zum Men  zur ckkehren, ohne weitere Aktionen aus dieser Eingabe zu verarbeiten
        continue 
    }

    $validActionChosenOrAttempted = $false
    $numberOfChoices = $choicesArray.Count
    $currentChoiceIndex = 0

    foreach ($choice in $choicesArray) {
        if ($choice -eq "P") { continue } # "P" wurde bereits behandelt

        $currentChoiceIndex++
        $actionInvokedAndSuccessful = $false
        $actionAttempted = $true 

        Write-Host "`n=============================================================================================================="
        Write-Host " Verarbeitung der Auswahl: '$choice' (Aktion $currentChoiceIndex von $numberOfChoices)" -ForegroundColor Yellow
        Write-Host "=============================================================================================================="
        Start-Sleep -Seconds 1

        switch ($choice) {
            "1" { $actionInvokedAndSuccessful = Backup-UserProfile }
            "2" { $actionInvokedAndSuccessful = Backup-ApplicationProfile -AppName "Firefox" -ProfilePathInUserDir "AppData\Roaming\Mozilla\Firefox" -ProcessName "firefox" }
            "3" { $actionInvokedAndSuccessful = Backup-ApplicationProfile -AppName "Edge" -ProfilePathInUserDir "AppData\Local\Microsoft\Edge\User Data\Default" -ProcessName "msedge" }
            "4" { $actionInvokedAndSuccessful = Backup-ApplicationProfile -AppName "Chrome" -ProfilePathInUserDir "AppData\Local\Google\Chrome\User Data\Default" -ProcessName "chrome" }
            "5" { $actionInvokedAndSuccessful = Backup-ApplicationProfile -AppName "Thunderbird" -ProfilePathInUserDir "AppData\Roaming\Thunderbird" -ProcessName "thunderbird" }
            "6" { $actionInvokedAndSuccessful = Export-WingetPackages }
            "7" { $actionInvokedAndSuccessful = Restore-UserProfile }
            "8" { $actionInvokedAndSuccessful = Restore-ApplicationProfile -AppName "Firefox" -ProfilePathInUserDir "AppData\Roaming\Mozilla\Firefox" -ProcessName "firefox" }
            "9" { $actionInvokedAndSuccessful = Restore-ApplicationProfile -AppName "Edge" -ProfilePathInUserDir "AppData\Local\Microsoft\Edge\User Data\Default" -ProcessName "msedge" }
            "10"{ $actionInvokedAndSuccessful = Restore-ApplicationProfile -AppName "Chrome" -ProfilePathInUserDir "AppData\Local\Google\Chrome\User Data\Default" -ProcessName "chrome" }
            "11"{ $actionInvokedAndSuccessful = Restore-ApplicationProfile -AppName "Thunderbird" -ProfilePathInUserDir "AppData\Roaming\Thunderbird" -ProcessName "thunderbird" }
            "12"{ $actionInvokedAndSuccessful = Import-WingetPackages }
            default {
                Write-Host "[FEHLER] Ungueltige Auswahl: '$choice'. Diese Auswahl wird uebersprungen." -ForegroundColor Red
                $actionAttempted = $false
            }
        }

        if ($actionAttempted) {
            $validActionChosenOrAttempted = $true
            if ($actionInvokedAndSuccessful) {
                Write-Host "[ERFOLG] Aktion '$choice' erfolgreich abgeschlossen." -ForegroundColor Green
            } else {
                Write-Host "[WARNUNG] Aktion '$choice' wurde NICHT erfolgreich ausgefuehrt oder vom Benutzer abgebrochen." -ForegroundColor Yellow
            }
        }
        
        if ($currentChoiceIndex -lt $numberOfChoices) { 
            if ($actionAttempted) {
                 Write-Host "`nNaechste Aktion in 10 Sekunden..."
                 Start-Sleep -Seconds 10
            } else {
                Write-Host "`nUngueltige Auswahl '$choice' uebersprungen. Fahre mit naechster Auswahl fort (falls vorhanden)..."
                Start-Sleep -Seconds 2 
            }
        }
    }

    if ($validActionChosenOrAttempted) {
        Write-Host "`nAlle ausgewaehlten Aktionen wurden abgearbeitet. Kehre zum Hauptmenue zurueck oder 'Q' zum Beenden." -ForegroundColor Green
        Write-Host "Druecken Sie eine Taste, um zum Menue zurueckzukehren..." -NoNewline
        if ($Host.Name -eq "ConsoleHost") { $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null } else { Read-Host | Out-Null }
    } elseif ($choicesArray.Count -gt 0 -and -not ($choicesArray -contains "P")) { # Nur pausieren, wenn ung ltige Eingaben gemacht wurden, aber nicht "P"
        Write-Host "`nKeine gueltigen Aktionen zur Ausfuehrung ausgewaehlt oder alle Eingaben waren ungueltig." -ForegroundColor Yellow
        Write-Host "Druecken Sie eine Taste, um zum Menue zurueckzukehren..." -NoNewline
        if ($Host.Name -eq "ConsoleHost") { $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null } else { Read-Host | Out-Null }
    }
    # Wenn keine Eingabe erfolgte (leere Zeile), wird die Schleife wiederholt und das Men  erneut angezeigt.

} while ($true) # Endlosschleife, Beendigung durch 'Q'

# Das Skript sollte hier nie ankommen, da es durch 'exit' in der Schleife oder Invoke-PauseAndExit beendet wird.
Write-Host "Das Skript wird in 5 Sekunden geschlossen."
Start-Sleep -Seconds 5