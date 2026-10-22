<#
.SYNOPSIS
    Obsill setup: picks the Obsidian vault, reads the daily note settings from it,
    writes config.json and verifies the result. Started by setup_obsill.bat.

.DESCRIPTION
    1. Looks for AutoHotkey v2.
    2. Opens a folder picker for the vault root (the folder that contains .obsidian).
    3. Reads <vault>\.obsidian\daily-notes.json (and core-plugins.json) for the
       daily note folder / date format / template.
    4. Asks for the global hotkey.
    5. Writes <project>\config.json (UTF-8, no BOM).
    6. Runs src\Obsill-Check.ahk to verify the config and show today's note path.
    7. Optionally adds a Startup shortcut and starts Obsill.

    Everything is logged to <project>\logs\setup.log. Works on Windows PowerShell 5.1.
    The script only READS from the vault. It never writes inside .obsidian.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$ScriptDir   = $PSScriptRoot
$ProjectRoot = Split-Path -Parent $ScriptDir
$LogDir      = Join-Path $ProjectRoot 'logs'
$LogFile     = Join-Path $LogDir 'setup.log'
$ConfigPath  = Join-Path $ProjectRoot 'config.json'
$AhkMain     = Join-Path $ScriptDir 'Obsill.ahk'
$AhkCheck    = Join-Path $ScriptDir 'Obsill-Check.ahk'
$CheckResult = Join-Path $LogDir 'check_result.txt'
$DefaultHotkey = '^!l'

# ------------------------------------------------------------------ logging / console

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $LogFile -Value ('{0} [{1}] {2}' -f $stamp, $Level, $Message) -Encoding UTF8
}

# Console + log.
function Write-Say {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    if ($Message -ne '') { Write-Log -Message $Message -Level $Level }
    switch ($Level) {
        'OK'    { $color = 'Green' }
        'WARN'  { $color = 'Yellow' }
        'ERROR' { $color = 'Red' }
        default { $color = 'Gray' }
    }
    Write-Host $Message -ForegroundColor $color
}

function Read-YesNo {
    param([Parameter(Mandatory)][string]$Question, [bool]$Default = $false)
    if ($Default) { $hint = '[Y/n]' } else { $hint = '[y/N]' }
    while ($true) {
        $answer = (Read-Host "$Question $hint").Trim()
        if ($answer -eq '') { Write-Log "Q: $Question -> (default) $Default"; return $Default }
        if ($answer -match '^(y|yes)$') { Write-Log "Q: $Question -> yes"; return $true }
        if ($answer -match '^(n|no)$')  { Write-Log "Q: $Question -> no";  return $false }
        Write-Host 'Please answer y or n.' -ForegroundColor Yellow
    }
}

function Read-WithDefault {
    param([Parameter(Mandatory)][string]$Prompt, [string]$Default = '')
    if ($Default -ne '') { $shown = "$Prompt [$Default]" } else { $shown = $Prompt }
    $answer = (Read-Host $shown).Trim()
    if ($answer -eq '') { $answer = $Default }
    Write-Log "Q: $Prompt -> '$answer'"
    return $answer
}

# ------------------------------------------------------------------ helpers

function Get-ObsillVersion {
    $file = Join-Path $ScriptDir 'lib\Version.ahk'
    if (Test-Path -LiteralPath $file) {
        $m = [regex]::Match([System.IO.File]::ReadAllText($file), 'static\s+Version\s*:=\s*"([^"]+)"')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return 'unknown'
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    $raw = [System.IO.File]::ReadAllText($Path)    # detects and strips a BOM
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "The file is empty: $Path" }
    $parsed = $raw | ConvertFrom-Json
    return , $parsed                                # the comma keeps arrays from being unrolled
}

function Get-JsonProp {
    param($Object, [Parameter(Mandatory)][string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $Default }
    return $prop.Value
}

# Vault-relative folder, "/" separated, no leading/trailing slash. Throws if it could leave the vault.
function ConvertTo-VaultRelativeFolder {
    param([AllowEmptyString()][string]$Folder)
    $parts = @()
    foreach ($part in ($Folder -replace '\\', '/').Split('/')) {
        $p = $part.Trim()
        if ($p -eq '' -or $p -eq '.') { continue }
        if ($p -eq '..') { throw "The daily note folder must stay inside the vault (found '..'): $Folder" }
        $parts += $p
    }
    if ($parts.Count -gt 0 -and $parts[0] -match '^[A-Za-z]:$') {
        throw "The daily note folder must be relative to the vault root, not a drive path: $Folder"
    }
    return ($parts -join '/')
}

function Find-AutoHotkeyV2 {
    $candidates = @()
    if ($env:OBSILL_AHK) { $candidates += $env:OBSILL_AHK }
    $candidates += (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe')
    $candidates += (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey32.exe')
    $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe')
    $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey32.exe')
    $onPath = Get-Command 'AutoHotkey64.exe', 'AutoHotkey32.exe', 'AutoHotkey.exe' -ErrorAction SilentlyContinue
    foreach ($cmd in @($onPath)) { if ($null -ne $cmd) { $candidates += $cmd.Source } }

    foreach ($path in $candidates) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $version = (Get-Item -LiteralPath $path).VersionInfo.FileVersion
        Write-Log "AutoHotkey candidate: $path (version $version)"
        if ($version -and $version -match '^2\.') { return $path }
    }
    return $null
}

function Select-Folder {
    param([Parameter(Mandatory)][string]$Description)
    Add-Type -AssemblyName System.Windows.Forms
    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
    $dialog.ShowNewFolderButton = $false
    try {
        if ($dialog.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath }
        return $null
    }
    finally {
        $dialog.Dispose()
        $owner.Dispose()
    }
}

# Walks up from $Path until a folder containing .obsidian is found.
function Find-VaultRoot {
    param([Parameter(Mandatory)][string]$Path)
    $current = Get-Item -LiteralPath $Path
    while ($null -ne $current) {
        if (Test-Path -LiteralPath (Join-Path $current.FullName '.obsidian') -PathType Container) { return $current.FullName }
        $current = $current.Parent
    }
    return $null
}

function Get-VaultRootFromUser {
    while ($true) {
        Write-Say 'A folder window will open. Select your Obsidian vault folder (the one that contains ".obsidian").'
        $picked = Select-Folder -Description 'Select your Obsidian vault folder (the one that contains .obsidian)'
        if (-not $picked) {
            Write-Say 'No folder was selected.' 'WARN'
            if (Read-YesNo 'Try again?' $true) { continue }
            return $null
        }
        Write-Log "Folder picked: $picked"
        $root = Find-VaultRoot -Path $picked
        if (-not $root) {
            Write-Say "That folder is not inside an Obsidian vault (no .obsidian folder in it or above it): $picked" 'WARN'
            continue
        }
        if ($root.TrimEnd('\') -ne $picked.TrimEnd('\')) {
            Write-Say "You picked a folder inside a vault. The vault root is: $root" 'WARN'
            if (-not (Read-YesNo 'Use that vault root?' $true)) { continue }
        }
        return $root
    }
}

# Reads the daily note settings the way Obsidian does: missing keys mean defaults.
function Get-DailyNoteSettings {
    param([Parameter(Mandatory)][string]$VaultRoot)

    $obsidianDir = Join-Path $VaultRoot '.obsidian'
    $result = [pscustomobject]@{
        Folder        = ''
        Format        = 'YYYY-MM-DD'
        Template      = ''
        PluginEnabled = $null
        FileFound     = $false
        Source        = 'Obsidian defaults (daily-notes.json not found)'
    }

    # Is the core Daily notes plugin enabled? (core-plugins.json is an object in new Obsidian versions, an array in old ones)
    $corePath = Join-Path $obsidianDir 'core-plugins.json'
    if (Test-Path -LiteralPath $corePath -PathType Leaf) {
        try {
            $core = Read-JsonFile -Path $corePath
            if ($null -eq $core) {
                $result.PluginEnabled = $false
            }
            elseif ($core -is [System.Array]) {
                $result.PluginEnabled = [bool]($core -contains 'daily-notes')
            }
            else {
                $prop = $core.PSObject.Properties['daily-notes']
                $result.PluginEnabled = ($null -ne $prop) -and ($prop.Value -eq $true)
            }
            Write-Log "core-plugins.json: daily-notes enabled = $($result.PluginEnabled)"
        }
        catch {
            Write-Log "Could not read core-plugins.json: $($_.Exception.Message)" 'WARN'
        }
    }
    else {
        Write-Log 'core-plugins.json not found.' 'WARN'
    }

    $dnPath = Join-Path $obsidianDir 'daily-notes.json'
    if (Test-Path -LiteralPath $dnPath -PathType Leaf) {
        $result.FileFound = $true
        try {
            $dn = Read-JsonFile -Path $dnPath
            Write-Log ('daily-notes.json content: ' + (($dn | ConvertTo-Json -Compress -Depth 4)))
            $folder   = Get-JsonProp $dn 'folder'
            $format   = Get-JsonProp $dn 'format'
            $template = Get-JsonProp $dn 'template'
            if ($folder -is [string]) { $result.Folder = $folder }
            if ($format -is [string] -and $format.Trim() -ne '') { $result.Format = $format.Trim() }
            if ($template -is [string]) { $result.Template = $template.Trim() }
            $result.Source = 'daily-notes.json'
        }
        catch {
            $result.FileFound = $false
            Write-Say "daily-notes.json exists but could not be read ($($_.Exception.Message)). Using Obsidian defaults." 'WARN'
            $result.Source = 'Obsidian defaults (daily-notes.json unreadable)'
        }
    }
    else {
        Write-Log 'daily-notes.json not found. Obsidian creates it the first time a Daily notes option is changed.' 'WARN'
    }
    return $result
}

function Save-Config {
    param([Parameter(Mandatory)]$Config)
    if (Test-Path -LiteralPath $ConfigPath) {
        Copy-Item -LiteralPath $ConfigPath -Destination "$ConfigPath.bak" -Force
        Write-Log 'Existing config.json was backed up to config.json.bak'
    }
    $json = $Config | ConvertTo-Json -Depth 5
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ConfigPath, $json + [Environment]::NewLine, $utf8NoBom)
    # prove that what we wrote can be read back
    $null = Read-JsonFile -Path $ConfigPath
    Write-Log "config.json written: $ConfigPath"
    Write-Log ("config.json content:`r`n" + $json)
}

function New-StartupShortcut {
    param([Parameter(Mandatory)][string]$AhkExe)
    $startupDir = [Environment]::GetFolderPath('Startup')
    $lnkPath = Join-Path $startupDir 'Obsill.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = $AhkExe
    $shortcut.Arguments = '"' + $AhkMain + '"'
    $shortcut.WorkingDirectory = $ProjectRoot
    $shortcut.Description = 'Obsill - Obsidian Life Logger'
    $shortcut.Save()
    return $lnkPath
}

# ------------------------------------------------------------------ main

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
if ((Test-Path -LiteralPath $LogFile) -and ((Get-Item -LiteralPath $LogFile).Length -gt 1MB)) {
    Move-Item -LiteralPath $LogFile -Destination "$LogFile.old" -Force
}

$ObsillVersion = Get-ObsillVersion
Write-Log '=================== Obsill setup started ==================='
Write-Log "Obsill version : $ObsillVersion"
Write-Log ('Windows        : ' + [Environment]::OSVersion.VersionString)
Write-Log ('PowerShell     : ' + $PSVersionTable.PSVersion)
Write-Log "Project folder : $ProjectRoot"

try {
    Write-Host ''
    Write-Host "  Obsill $ObsillVersion  -  Obsidian Life Logger  -  setup" -ForegroundColor Cyan
    Write-Host '  ------------------------------------------------------' -ForegroundColor Cyan
    Write-Host ''

    # 1. AutoHotkey v2
    $ahkExe = Find-AutoHotkeyV2
    if ($ahkExe) {
        Write-Say "[1/6] AutoHotkey v2 found: $ahkExe" 'OK'
    }
    else {
        Write-Say '[1/6] AutoHotkey v2 was NOT found.' 'WARN'
        Write-Say '      Install it from https://www.autohotkey.com (version 2.x) and run this setup again.' 'WARN'
        Write-Say '      Setup can still write config.json, but the check and the launch will be skipped.' 'WARN'
    }

    # 2. existing config
    if (Test-Path -LiteralPath $ConfigPath) {
        $oldVault = ''
        try { $oldVault = [string](Get-JsonProp (Read-JsonFile -Path $ConfigPath) 'vaultRoot' '') } catch { }
        Write-Say "[2/6] A config.json already exists (vault: $oldVault)." 'WARN'
        if (-not (Read-YesNo 'Replace it? (the old one is kept as config.json.bak)' $true)) {
            Write-Say 'Setup cancelled. Nothing was changed.' 'WARN'
            Write-Log '=== Setup cancelled by the user (existing config kept) ==='
            exit 0
        }
    }
    else {
        Write-Say '[2/6] No config.json yet. This is a first-time setup.'
    }

    # 3. vault
    Write-Say '[3/6] Choose your Obsidian vault.'
    $vaultRoot = Get-VaultRootFromUser
    if (-not $vaultRoot) {
        Write-Say 'Setup cancelled: no vault was selected.' 'ERROR'
        Write-Log '=== Setup cancelled: no vault selected ==='
        exit 1
    }
    Write-Say "      Vault root: $vaultRoot" 'OK'

    # 4. daily note settings from the vault
    Write-Say '[4/6] Reading the daily note settings from the vault (.obsidian\daily-notes.json).'
    $dn = Get-DailyNoteSettings -VaultRoot $vaultRoot
    $folder = ConvertTo-VaultRelativeFolder -Folder $dn.Folder
    $format = $dn.Format
    $template = $dn.Template
    if ($folder -eq '') { $folderShown = '(vault root)' } else { $folderShown = $folder }
    if ($template -eq '') { $templateShown = '(none)' } else { $templateShown = "$template  (v0.0.1 does not apply templates)" }
    Write-Say "      source   : $($dn.Source)"
    Write-Say "      folder   : $folderShown"
    Write-Say "      format   : $format"
    Write-Say "      template : $templateShown"
    if ($dn.PluginEnabled -eq $false) {
        Write-Say '      Note: the core "Daily notes" plugin looks disabled in this vault. Obsill will still use these values.' 'WARN'
    }
    if (-not $dn.FileFound) {
        Write-Say '      Note: daily-notes.json does not exist (or is unreadable), so Obsidian defaults are shown.' 'WARN'
        Write-Say '      Open Obsidian > Settings > Daily notes, set your folder/format, then run this setup again.' 'WARN'
    }

    $mode = 'auto'
    Write-Host ''
    Write-Say '      Automatic mode: Obsill re-reads these settings from Obsidian every time you log,' 
    Write-Say '      so changing them in Obsidian needs no new setup.'
    if (-not (Read-YesNo '      Use automatic mode?' $true)) {
        $mode = 'manual'
        while ($true) {
            $folder = Read-WithDefault -Prompt '      Daily note folder (relative to the vault root)' -Default $folder
            try { $folder = ConvertTo-VaultRelativeFolder -Folder $folder; break }
            catch { Write-Say "      $($_.Exception.Message)" 'WARN' }
        }
        $format = Read-WithDefault -Prompt '      Date format (same as in Obsidian)' -Default $format
    }
    Write-Log "Daily note mode: $mode"

    # 5. hotkey
    Write-Say '[5/6] Choose the global hotkey.'
    Write-Say '      AutoHotkey syntax: ^ = Ctrl   ! = Alt   + = Shift   # = Windows key.  ^!l means Ctrl+Alt+L.'
    $hotkey = Read-WithDefault -Prompt '      Hotkey' -Default $DefaultHotkey

    # 6. write config
    Write-Say '[6/6] Writing config.json.'
    $config = [ordered]@{
        obsillVersion = $ObsillVersion
        vaultRoot     = $vaultRoot
        hotkey        = $hotkey
        dailyNoteMode = $mode
        dailyNote     = [ordered]@{
            folder   = $folder
            format   = $format
            template = $template
        }
        timeFormat    = 'HH:mm'
        entryTemplate = '- {time} {text}'
    }
    Save-Config -Config $config
    Write-Say "      Saved: $ConfigPath" 'OK'

    # verification with the real converter
    $checkPassed = $null
    if ($ahkExe) {
        Write-Host ''
        Write-Say 'Verifying with the Obsill self-check...'
        if (Test-Path -LiteralPath $CheckResult) { Remove-Item -LiteralPath $CheckResult -Force }
        $checkScript = '"' + $AhkCheck + '"'
        $proc = Start-Process -FilePath $ahkExe -ArgumentList @($checkScript, '/silent') -PassThru
        $null = $proc.Handle    # caches the handle so ExitCode is readable afterwards
        if ($proc.WaitForExit(30000)) {
            $checkPassed = ($proc.ExitCode -eq 0)
            Write-Log "Self-check exit code: $($proc.ExitCode)"
        }
        else {
            try { $proc.Kill() } catch { }
            $checkPassed = $false
            Write-Say 'The self-check did not finish within 30 seconds (an AutoHotkey error window may be open behind this one).' 'WARN'
        }
        if (Test-Path -LiteralPath $CheckResult) {
            foreach ($line in (Get-Content -LiteralPath $CheckResult)) {
                $lineLevel = 'INFO'
                if ($line -match '\[FAIL\]') { $lineLevel = 'ERROR' }
                elseif ($line -match 'RESULT: PASS') { $lineLevel = 'OK' }
                Write-Say "  $line" $lineLevel
            }
        }
        else {
            Write-Say 'The self-check produced no report. See logs\obsill.log.' 'WARN'
        }
    }

    # optional: startup shortcut and launch
    if ($ahkExe -and $checkPassed) {
        Write-Host ''
        if (Read-YesNo 'Start Obsill automatically when Windows starts?' $false) {
            $lnk = New-StartupShortcut -AhkExe $ahkExe
            Write-Say "Startup shortcut created: $lnk" 'OK'
        }
        if (Read-YesNo 'Start Obsill now?' $true) {
            Start-Process -FilePath $ahkExe -ArgumentList ('"' + $AhkMain + '"') -WorkingDirectory $ProjectRoot
            Write-Say "Obsill is running. Press $hotkey to log." 'OK'
        }
    }
    elseif ($ahkExe -and ($checkPassed -eq $false)) {
        Write-Say 'The self-check reported a problem, so Obsill was not started. Fix it (see above) and run setup again.' 'ERROR'
        Write-Log '=== Setup finished WITH PROBLEMS ==='
        exit 1
    }

    if (-not $ahkExe) {
        Write-Host ''
        Write-Say 'Reminder: install AutoHotkey v2 (https://www.autohotkey.com), then run start_obsill.bat to launch Obsill.' 'WARN'
    }
    Write-Host ''
    Write-Say 'Setup finished.' 'OK'
    Write-Say "Setup log: $LogFile"
    Write-Log '=================== Setup finished OK ==================='
    exit 0
}
catch {
    Write-Log ('Setup failed: ' + $_.Exception.Message) 'ERROR'
    Write-Log ('At: ' + $_.InvocationInfo.PositionMessage) 'ERROR'
    if ($_.ScriptStackTrace) { Write-Log ('Stack: ' + $_.ScriptStackTrace) 'ERROR' }
    Write-Host ''
    Write-Host ('Setup failed: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host "Details were written to: $LogFile" -ForegroundColor Red
    exit 1
}
