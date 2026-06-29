#requires -Version 3.0
<#
.SYNOPSIS
    Removes the OpenUSD language support files (or symlinks) from Notepad++.

.DESCRIPTION
    Deletes:
      - %AppData%\Notepad++\userDefineLangs\OpenUSD.udl.xml
      - <Notepad++ install dir>\autoCompletion\OpenUSD.xml   (may need Administrator)

    Works whether the items were copied or symlinked. Restart Notepad++ afterwards.
    Note: the "OpenUSD" entry may linger in the Language menu until you also remove it
    via Language -> User Defined Language -> Define your language -> Remove, if it was
    ever imported through that dialog.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
#>

[CmdletBinding()]
param([string]$NotepadPlusPlusDir)

$ErrorActionPreference = 'Stop'

function Remove-Target {
    param([string]$Path)
    if (-not (Test-Path $Path)) { Write-Host "[skip] not present: $Path"; return }
    try {
        Remove-Item -Path $Path -Force -ErrorAction Stop
        Write-Host "[ok] removed: $Path" -ForegroundColor Green
    } catch {
        Write-Warning "Could not remove '$Path' (may need Administrator)."
    }
}

# 1. UDL in %AppData%
Remove-Target (Join-Path $env:APPDATA 'Notepad++\userDefineLangs\OpenUSD.udl.xml')

# 2. Autocompletion in the install dir
$nppDir = $NotepadPlusPlusDir
if (-not $nppDir) {
    foreach ($c in @((Join-Path $env:ProgramFiles 'Notepad++'), (Join-Path ${env:ProgramFiles(x86)} 'Notepad++'))) {
        if ($c -and (Test-Path (Join-Path $c 'notepad++.exe'))) { $nppDir = $c; break }
    }
}
if ($nppDir) {
    Remove-Target (Join-Path $nppDir 'autoCompletion\OpenUSD.xml')
} else {
    Write-Warning "Notepad++ install dir not found; remove '<install dir>\autoCompletion\OpenUSD.xml' manually."
}

# 3. PythonScript .usd auto-detect hook, binary-viewer config, startup.py block
$psUserScripts = Join-Path $env:APPDATA 'Notepad++\plugins\Config\PythonScript\scripts'
Remove-Target (Join-Path $psUserScripts 'OpenUSD_usd_autodetect.py')
Remove-Target (Join-Path $psUserScripts 'OpenUSD_view.cfg')
$startup = Join-Path $psUserScripts 'startup.py'
if (Test-Path $startup) {
    $beginMark = '# >>> OpenUSD .usd autodetect (managed by install.ps1) >>>'
    $endMark   = '# <<< OpenUSD .usd autodetect <<<'
    $txt = [System.IO.File]::ReadAllText($startup)
    $pattern = '(?s)\r?\n?' + [regex]::Escape($beginMark) + '.*?' + [regex]::Escape($endMark) + '\r?\n?'
    $new = [regex]::Replace($txt, $pattern, '')
    if ($new -ne $txt) {
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        if ($new.Trim().Length -eq 0) {
            Remove-Item -Path $startup -Force
            Write-Host "[ok] removed empty startup.py: $startup" -ForegroundColor Green
        } else {
            [System.IO.File]::WriteAllText($startup, $new, $utf8)
            Write-Host "[ok] unregistered hook from $startup" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Done. Restart Notepad++." -ForegroundColor Cyan
