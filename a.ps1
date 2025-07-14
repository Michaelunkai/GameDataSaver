# Prompt for game name
$game = Read-Host "Enter the name of the game (case-sensitive folder name)"

# Ask whether to backup or restore
$action = Read-Host "Type 'backup' to save or 'restore' to recover"

# Expanded search paths to handle publisher subfolders
$locations = @(
    "$env:APPDATA\$game",
    "$env:LOCALAPPDATA\$game",
    "$env:APPDATA\..\LocalLow\$game",
    "$env:USERPROFILE\Documents\$game",
    "$env:USERPROFILE\Saved Games\$game",
    "$env:APPDATA\*\$game",
    "$env:LOCALAPPDATA\*\$game",
    "$env:APPDATA\..\LocalLow\*\$game",
    "$env:USERPROFILE\Documents\*\$game",
    "$env:USERPROFILE\Saved Games\*\$game"
)

# Try to find the correct game save path
$savePath = $null
foreach ($pattern in $locations) {
    Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_ -ne $null -and $_.Name -ieq $game) {
            $savePath = $_.FullName
            break
        }
    }
    if ($savePath) { break }
}

if (-not $savePath) {
    Write-Host "❌ Could not find save folder for '$game'" -ForegroundColor Red
    exit 1
}

# Set base backup location
$backupBase = "F:\backup\gamesaves\$game"

# Perform selected action
switch ($action.ToLower()) {
    'backup' {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $dest = Join-Path $backupBase $timestamp
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Item $savePath -Destination $dest -Recurse -Force
        Write-Host "✅ Backup completed to $dest" -ForegroundColor Green
    }

    'restore' {
        if (-not (Test-Path $backupBase)) {
            Write-Host "❌ No backups found for '$game'" -ForegroundColor Red
            exit 1
        }

        $latestBackup = Get-ChildItem $backupBase | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $latestBackup) {
            Write-Host "❌ No backups available to restore" -ForegroundColor Red
            exit 1
        }

        Copy-Item "$($latestBackup.FullName)\*" -Destination $savePath -Recurse -Force
        Write-Host "✅ Restore completed from $($latestBackup.FullName)" -ForegroundColor Green
    }

    default {
        Write-Host "❌ Invalid action. Please type 'backup' or 'restore'." -ForegroundColor Red
    }
}

