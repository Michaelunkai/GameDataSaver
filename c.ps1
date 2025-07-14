# Enhanced Game Save Backup/Restore Script
# Supports single-letter commands and comprehensive game data detection

# Prompt for game name
$game = Read-Host "Enter the name of the game"

# Ask whether to backup or restore (accept single letters)
$action = Read-Host "Type 'b' for backup or 'r' for restore"

# Comprehensive search paths for game saves
$locations = @(
    # Standard Windows save locations
    "$env:APPDATA\$game",
    "$env:LOCALAPPDATA\$game", 
    "$env:APPDATA\..\LocalLow\$game",
    "$env:USERPROFILE\Documents\$game",
    "$env:USERPROFILE\Saved Games\$game",
    "$env:USERPROFILE\Games\$game",
    
    # Publisher subdirectories
    "$env:APPDATA\*\$game",
    "$env:LOCALAPPDATA\*\$game",
    "$env:APPDATA\..\LocalLow\*\$game",
    "$env:USERPROFILE\Documents\*\$game",
    "$env:USERPROFILE\Saved Games\*\$game",
    "$env:USERPROFILE\Games\*\$game",
    
    # Steam locations
    "$env:USERPROFILE\Documents\My Games\$game",
    "$env:USERPROFILE\Documents\My Games\*\$game",
    "$env:APPDATA\Steam\*\$game",
    "$env:LOCALAPPDATA\Steam\*\$game",
    
    # Epic Games locations
    "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\*\$game",
    "$env:APPDATA\EpicGamesLauncher\*\$game",
    
    # Origin/EA locations
    "$env:USERPROFILE\Documents\Electronic Arts\$game",
    "$env:USERPROFILE\Documents\Electronic Arts\*\$game",
    "$env:APPDATA\Origin\*\$game",
    "$env:LOCALAPPDATA\Origin\*\$game",
    
    # Ubisoft locations
    "$env:USERPROFILE\Documents\My Games\Ubisoft\$game",
    "$env:USERPROFILE\Documents\My Games\Ubisoft\*\$game",
    "$env:APPDATA\Ubisoft\*\$game",
    "$env:LOCALAPPDATA\Ubisoft\*\$game",
    
    # GOG locations
    "$env:USERPROFILE\Documents\GOG.com\$game",
    "$env:USERPROFILE\Documents\GOG.com\*\$game",
    "$env:APPDATA\GOG.com\*\$game",
    "$env:LOCALAPPDATA\GOG.com\*\$game",
    
    # Windows Store/Xbox locations
    "$env:LOCALAPPDATA\Packages\*$game*",
    "$env:USERPROFILE\Documents\Xbox\$game",
    
    # Additional common locations
    "$env:USERPROFILE\AppData\Roaming\$game",
    "$env:USERPROFILE\AppData\Local\$game",
    "$env:USERPROFILE\AppData\LocalLow\$game",
    "$env:PROGRAMDATA\$game",
    "$env:ALLUSERSPROFILE\$game"
)

# Function to find game save path with comprehensive search
function Find-GameSavePath {
    param($gameName)
    
    Write-Host "Searching for '$gameName' save data..." -ForegroundColor Yellow
    
    $foundPaths = @()
    
    foreach ($pattern in $locations) {
        try {
            # Handle wildcards in path
            if ($pattern -like "*`**") {
                $basePath = $pattern -replace '\*[^\\]*$', ''
                $searchPattern = ($pattern -split '\\')[-1]
                
                if (Test-Path $basePath) {
                    Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                        $subPath = Join-Path $_.FullName $searchPattern
                        Get-ChildItem -Path $subPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                            if ($_.Name -like "*$gameName*") {
                                $foundPaths += $_.FullName
                            }
                        }
                    }
                }
            } else {
                # Direct path check
                if (Test-Path $pattern) {
                    $item = Get-Item $pattern -ErrorAction SilentlyContinue
                    if ($item -and $item.PSIsContainer) {
                        $foundPaths += $item.FullName
                    }
                }
            }
        } catch {
            # Silently continue on access errors
        }
    }
    
    # Also search for partial matches in common directories
    $commonDirs = @(
        "$env:APPDATA",
        "$env:LOCALAPPDATA", 
        "$env:APPDATA\..\LocalLow",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Saved Games"
    )
    
    foreach ($dir in $commonDirs) {
        if (Test-Path $dir) {
            try {
                Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.Name -like "*$gameName*") {
                        $foundPaths += $_.FullName
                    }
                }
            } catch {
                # Silently continue
            }
        }
    }
    
    # Remove duplicates and sort by relevance
    $foundPaths = $foundPaths | Sort-Object -Unique
    
    if ($foundPaths.Count -eq 0) {
        return $null
    } elseif ($foundPaths.Count -eq 1) {
        return $foundPaths[0]
    } else {
        # Multiple matches found, let user choose
        Write-Host "Multiple save locations found:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $foundPaths.Count; $i++) {
            Write-Host "[$($i + 1)] $($foundPaths[$i])" -ForegroundColor White
        }
        
        do {
            $choice = Read-Host "Select the correct save location (1-$($foundPaths.Count))"
            $choiceNum = [int]$choice - 1
        } while ($choiceNum -lt 0 -or $choiceNum -ge $foundPaths.Count)
        
        return $foundPaths[$choiceNum]
    }
}

# Find the game save path
$savePath = Find-GameSavePath $game

if (-not $savePath) {
    Write-Host "❌ Could not find save folder for '$game'" -ForegroundColor Red
    Write-Host "Try checking the exact spelling or look for the game folder manually." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Found save data at: $savePath" -ForegroundColor Green

# Set base backup location
$backupBase = "F:\backup\gamesaves\$game"

# Perform selected action (case-insensitive, accepts single letters)
switch ($action.ToLower()) {
    {$_ -in @('b', 'backup')} {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $dest = Join-Path $backupBase $timestamp
        
        try {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Copy-Item "$savePath\*" -Destination $dest -Recurse -Force
            Write-Host "✅ Backup completed to $dest" -ForegroundColor Green
            Write-Host "📁 Backed up: $(Get-ChildItem $dest -Recurse | Measure-Object).Count files" -ForegroundColor Cyan
        } catch {
            Write-Host "❌ Backup failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    {$_ -in @('r', 'restore')} {
        if (-not (Test-Path $backupBase)) {
            Write-Host "❌ No backups found for '$game'" -ForegroundColor Red
            exit 1
        }

        $backups = Get-ChildItem $backupBase -Directory | Sort-Object LastWriteTime -Descending
        
        if ($backups.Count -eq 0) {
            Write-Host "❌ No backups available to restore" -ForegroundColor Red
            exit 1
        }

        if ($backups.Count -eq 1) {
            $selectedBackup = $backups[0]
        } else {
            Write-Host "Available backups:" -ForegroundColor Cyan
            for ($i = 0; $i -lt [Math]::Min($backups.Count, 10); $i++) {
                $backup = $backups[$i]
                Write-Host "[$($i + 1)] $($backup.Name) - $($backup.LastWriteTime)" -ForegroundColor White
            }
            
            do {
                $choice = Read-Host "Select backup to restore (1-$([Math]::Min($backups.Count, 10))) or press Enter for latest"
                if ([string]::IsNullOrEmpty($choice)) {
                    $selectedBackup = $backups[0]
                    break
                }
                $choiceNum = [int]$choice - 1
            } while ($choiceNum -lt 0 -or $choiceNum -ge [Math]::Min($backups.Count, 10))
            
            if (-not $selectedBackup) {
                $selectedBackup = $backups[$choiceNum]
            }
        }

        try {
            # Create backup of current saves before restoring
            $preRestoreBackup = Join-Path $backupBase "pre-restore-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
            New-Item -ItemType Directory -Path $preRestoreBackup -Force | Out-Null
            Copy-Item "$savePath\*" -Destination $preRestoreBackup -Recurse -Force -ErrorAction SilentlyContinue
            
            # Restore from selected backup
            Remove-Item "$savePath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item "$($selectedBackup.FullName)\*" -Destination $savePath -Recurse -Force
            
            Write-Host "✅ Restore completed from $($selectedBackup.Name)" -ForegroundColor Green
            Write-Host "📁 Current saves backed up to: $preRestoreBackup" -ForegroundColor Cyan
        } catch {
            Write-Host "❌ Restore failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    default {
        Write-Host "❌ Invalid action. Please type 'b' for backup or 'r' for restore." -ForegroundColor Red
    }
}