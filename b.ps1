# Enhanced Game Save Backup/Restore Script with Memory and Suggestions
# History file to remember previous games
$historyFile = "$env:USERPROFILE\.gamesave_history.json"

# Function to load history
function Get-GameHistory {
    if (Test-Path $historyFile) {
        try {
            $content = Get-Content $historyFile -Raw | ConvertFrom-Json
            return $content
        } catch {
            return @{ backups = @(); restores = @() }
        }
    } else {
        return @{ backups = @(); restores = @() }
    }
}

# Function to save history
function Save-GameHistory {
    param($history)
    $history | ConvertTo-Json -Depth 3 | Set-Content $historyFile
}

# Function to add game to history
function Add-ToHistory {
    param($gameName, $action)
    $history = Get-GameHistory
    
    if ($action -eq 'backup') {
        $history.backups = @($gameName) + ($history.backups | Where-Object { $_ -ne $gameName })
        if ($history.backups.Count -gt 10) { $history.backups = $history.backups[0..9] }
    } else {
        $history.restores = @($gameName) + ($history.restores | Where-Object { $_ -ne $gameName })
        if ($history.restores.Count -gt 10) { $history.restores = $history.restores[0..9] }
    }
    
    Save-GameHistory $history
}

# Function to display suggestions
function Show-Suggestions {
    param($action)
    $history = Get-GameHistory
    
    $suggestions = if ($action -eq 'backup') { $history.backups } else { $history.restores }
    
    if ($suggestions -and $suggestions.Count -gt 0) {
        Write-Host "`nRecent ${action}s:" -ForegroundColor Cyan
        for ($i = 0; $i -lt [Math]::Min($suggestions.Count, 5); $i++) {
            Write-Host "  $($i + 1). $($suggestions[$i])" -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

# Clear screen for better presentation
Clear-Host
Write-Host "=== Game Save Backup/Restore Tool ===" -ForegroundColor Magenta
Write-Host ""

# Ask for action first to determine which suggestions to show
do {
    $action = Read-Host "Type 'b' for backup or 'r' for restore"
    $actionLower = $action.ToLower()
} while ($actionLower -ne 'b' -and $actionLower -ne 'r' -and $actionLower -ne 'backup' -and $actionLower -ne 'restore')

# Normalize action
$normalizedAction = switch ($actionLower) {
    'b' { 'backup' }
    'r' { 'restore' }
    default { $actionLower }
}

# Show suggestions based on action
Show-Suggestions $normalizedAction

# Prompt for game name with suggestions
$game = Read-Host "Enter the name of the game (case-sensitive folder name)"

# Check if user entered a number to select from suggestions
$history = Get-GameHistory
$suggestions = if ($normalizedAction -eq 'backup') { $history.backups } else { $history.restores }

if ($game -match '^\d+$' -and $suggestions -and [int]$game -le $suggestions.Count -and [int]$game -gt 0) {
    $game = $suggestions[[int]$game - 1]
    Write-Host "Selected: $game" -ForegroundColor Green
}

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

Write-Host "Searching for save files..." -ForegroundColor Cyan

# Try to find the correct game save path
$savePath = $null
foreach ($pattern in $locations) {
    Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_ -ne $null -and $_.Name -ieq $game) {
            $savePath = $_.FullName
            Write-Host "Found save folder: $savePath" -ForegroundColor Green
            break
        }
    }
    if ($savePath) { break }
}

if (-not $savePath) {
    Write-Host "❌ Could not find save folder for '$game'" -ForegroundColor Red
    Write-Host "Common locations searched:" -ForegroundColor Yellow
    $locations | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
    pause
    exit 1
}

# Set base backup location
$backupBase = "F:\backup\gamesaves\$game"

# Perform selected action
switch ($normalizedAction) {
    'backup' {
        Write-Host "Creating backup..." -ForegroundColor Cyan
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $dest = Join-Path $backupBase $timestamp
        
        try {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Copy-Item $savePath -Destination $dest -Recurse -Force
            
            # Add to history
            Add-ToHistory $game 'backup'
            
            Write-Host "✅ Backup completed to $dest" -ForegroundColor Green
            Write-Host "Size: $([math]::Round((Get-ChildItem $dest -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2)) MB" -ForegroundColor Gray
        } catch {
            Write-Host "❌ Backup failed: $_" -ForegroundColor Red
        }
    }
    'restore' {
        if (-not (Test-Path $backupBase)) {
            Write-Host "❌ No backups found for '$game'" -ForegroundColor Red
            pause
            exit 1
        }
        
        # Show available backups
        $backups = Get-ChildItem $backupBase | Sort-Object LastWriteTime -Descending
        if (-not $backups) {
            Write-Host "❌ No backups available to restore" -ForegroundColor Red
            pause
            exit 1
        }
        
        Write-Host "`nAvailable backups:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $backups.Count; $i++) {
            $backup = $backups[$i]
            $size = [math]::Round((Get-ChildItem $backup.FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
            Write-Host "  $($i + 1). $($backup.Name) (${size} MB) - $($backup.LastWriteTime)" -ForegroundColor Yellow
        }
        
        $selection = Read-Host "`nSelect backup number (or press Enter for latest)"
        
        if ([string]::IsNullOrWhiteSpace($selection)) {
            $selectedBackup = $backups[0]
        } elseif ($selection -match '^\d+$' -and [int]$selection -le $backups.Count -and [int]$selection -gt 0) {
            $selectedBackup = $backups[[int]$selection - 1]
        } else {
            Write-Host "❌ Invalid selection" -ForegroundColor Red
            pause
            exit 1
        }
        
        Write-Host "Restoring from: $($selectedBackup.Name)" -ForegroundColor Cyan
        
        try {
            # Create backup of current saves before restore
            $preRestoreBackup = Join-Path $backupBase "pre-restore_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
            New-Item -ItemType Directory -Path $preRestoreBackup -Force | Out-Null
            Copy-Item $savePath -Destination $preRestoreBackup -Recurse -Force
            Write-Host "Current saves backed up to: $preRestoreBackup" -ForegroundColor Gray
            
            # Perform restore
            Remove-Item "$savePath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item "$($selectedBackup.FullName)\*" -Destination $savePath -Recurse -Force
            
            # Add to history
            Add-ToHistory $game 'restore'
            
            Write-Host "✅ Restore completed from $($selectedBackup.FullName)" -ForegroundColor Green
        } catch {
            Write-Host "❌ Restore failed: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")