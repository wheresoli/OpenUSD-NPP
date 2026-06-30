#requires -Version 3.0
<#
.SYNOPSIS
    Installs the OpenUSD language support files into Notepad++.

.DESCRIPTION
    - Installs the User Defined Language (UDL) into  %AppData%\Notepad++\userDefineLangs\
    - Installs the autocompletion file into the Notepad++ install dir  autoCompletion\OpenUSD.xml
      (under Program Files, so an elevated shell may be needed).
    - If the PythonScript plugin is present, installs the optional .usd auto-detect
      hook and registers it in the user startup.py (so ASCII .usd files get the
      OpenUSD language while binary crate files are left alone).
    - With -BinaryViewer, also `pip install`s the official 'usd-core' package and
      enables editing of binary USD (crate) files: opening a .usdc converts it to a
      temp .usda you edit, and saving converts it back to the crate (only if it
      parses). Needs the PythonScript plugin and a Python 3.9-3.14.

    Close all Notepad++ windows before running, then reopen.

.PARAMETER Symlink
    Create symbolic links instead of copying, so edits in this repo go live.
    Needs Windows Developer Mode or an elevated shell.

.PARAMETER BinaryViewer
    Install/enable binary-USD (crate) round-trip editing (runs `pip install usd-core`).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Symlink -BinaryViewer
#>

[CmdletBinding()]
param(
    [string]$NotepadPlusPlusDir,
    [switch]$Symlink,
    [switch]$BinaryViewer
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$udlSrc  = Join-Path $here 'OpenUSD.udl.xml'
$acSrc   = Join-Path $here 'OpenUSD.autocomplete.xml'
$hookSrc = Join-Path $here 'scripts\OpenUSD_usd_autodetect.py'

if (-not (Test-Path $udlSrc)) { throw "Cannot find $udlSrc" }
if (-not (Test-Path $acSrc))  { throw "Cannot find $acSrc" }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$verb = if ($Symlink) { 'linked' } else { 'copied' }

# Copy or symlink a single file. Returns $true on success.
function Install-File {
    param([string]$Src, [string]$Dst, [switch]$AsSymlink)
    try {
        if (Test-Path $Dst) { Remove-Item -Path $Dst -Force -ErrorAction Stop }
        if ($AsSymlink) {
            # cmd's mklink honours Developer Mode without elevation, unlike
            # New-Item -SymbolicLink on Windows PowerShell 5.1.
            cmd /c mklink "$Dst" "$Src" | Out-Null
            if (-not (Test-Path $Dst)) { throw 'mklink failed' }
        } else {
            Copy-Item -Path $Src -Destination $Dst -Force -ErrorAction Stop
        }
        return $true
    } catch { return $false }
}

# --- 1. User Defined Language --------------------------------------------
$udlDir = Join-Path $env:APPDATA 'Notepad++\userDefineLangs'
if (-not (Test-Path $udlDir)) { New-Item -ItemType Directory -Force -Path $udlDir | Out-Null }
$udlDst = Join-Path $udlDir 'OpenUSD.udl.xml'
if (Install-File -Src $udlSrc -Dst $udlDst -AsSymlink:$Symlink) {
    Write-Host "[ok] UDL $verb -> $udlDst" -ForegroundColor Green
} else {
    Write-Warning "Failed to install UDL to $udlDst (try an elevated shell, or enable Developer Mode for -Symlink)."
}

# --- 2. Locate Notepad++ install dir -------------------------------------
function Find-NppDir {
    param([string]$Override)
    if ($Override) { return $Override }
    $candidates = @()
    foreach ($key in @('HKLM:\SOFTWARE\Notepad++', 'HKLM:\SOFTWARE\WOW6432Node\Notepad++')) {
        try {
            $val = (Get-ItemProperty -Path $key -ErrorAction Stop).'(default)'
            if ($val) { $candidates += $val }
        } catch {}
    }
    $candidates += @((Join-Path $env:ProgramFiles 'Notepad++'), (Join-Path ${env:ProgramFiles(x86)} 'Notepad++'))
    foreach ($c in $candidates) {
        if ($c -and (Test-Path (Join-Path $c 'notepad++.exe'))) { return $c }
    }
    return $null
}
$nppDir = Find-NppDir -Override $NotepadPlusPlusDir

# --- 3. Autocompletion ----------------------------------------------------
if (-not $nppDir) {
    Write-Warning "Could not locate the Notepad++ install directory."
    Write-Warning "Copy '$acSrc' manually to '<Notepad++ install dir>\autoCompletion\OpenUSD.xml'."
    Write-Warning "Or re-run with:  -NotepadPlusPlusDir 'C:\Path\To\Notepad++'"
} else {
    $acDir = Join-Path $nppDir 'autoCompletion'
    if (-not (Test-Path $acDir)) { New-Item -ItemType Directory -Force -Path $acDir | Out-Null }
    $acDst = Join-Path $acDir 'OpenUSD.xml'
    if (Install-File -Src $acSrc -Dst $acDst -AsSymlink:$Symlink) {
        Write-Host "[ok] Autocompletion $verb -> $acDst" -ForegroundColor Green
    } else {
        Write-Warning "Could not write to '$acDir' (under Program Files -> needs Administrator)."
        Write-Warning "Re-run this script from an elevated PowerShell$(if($Symlink){' -Symlink'})."
    }
}

# --- 4. Optional PythonScript hook (.usd auto-detect + crate editing) -----
$psConfigDir   = Join-Path $env:APPDATA 'Notepad++\plugins\Config\PythonScript'
$psUserScripts = Join-Path $psConfigDir 'scripts'
$psInstalled = (Test-Path $psConfigDir) -or
               (Test-Path (Join-Path $env:APPDATA 'Notepad++\plugins\PythonScript\PythonScript.dll')) -or
               ($nppDir -and (Test-Path (Join-Path $nppDir 'plugins\PythonScript\PythonScript.dll')))

if (-not $psInstalled) {
    Write-Host "[skip] PythonScript not detected -> .usd auto-detect not configured." -ForegroundColor DarkGray
    Write-Host "       (Install it via Plugins > Plugins Admin, then re-run. See README.)" -ForegroundColor DarkGray
    if ($BinaryViewer) { Write-Warning "-BinaryViewer needs the PythonScript plugin; skipping crate editing." }
} else {
    if (-not (Test-Path $psUserScripts)) { New-Item -ItemType Directory -Force -Path $psUserScripts | Out-Null }
    $hookDst = Join-Path $psUserScripts 'OpenUSD_usd_autodetect.py'

    if (Install-File -Src $hookSrc -Dst $hookDst -AsSymlink:$Symlink) {
        Write-Host "[ok] PythonScript hook $verb -> $hookDst" -ForegroundColor Green

        # Register (or refresh) the hook in the user startup.py.
        $startup   = Join-Path $psUserScripts 'startup.py'
        $beginMark = '# >>> OpenUSD .usd autodetect (managed by install.ps1) >>>'
        $endMark   = '# <<< OpenUSD .usd autodetect <<<'
        $blockLines = @(
            $beginMark,
            "_HOOK_DIR = r'$psUserScripts'",
            "_p = r'$hookDst'",
            'try:',
            '    exec(compile(open(_p).read(), _p, ''exec''))',
            'except Exception:',
            '    pass',
            $endMark
        )
        $block = ($blockLines -join "`r`n")
        $existing = if (Test-Path $startup) { [System.IO.File]::ReadAllText($startup) } else { '' }
        # Strip any prior managed block, then append the fresh one (keeps it current).
        $pattern  = '(?s)\r?\n?' + [regex]::Escape($beginMark) + '.*?' + [regex]::Escape($endMark) + '\r?\n?'
        $stripped = [regex]::Replace($existing, $pattern, '')
        $sep = if ($stripped.Trim().Length) { "`r`n`r`n" } else { '' }
        [System.IO.File]::WriteAllText($startup, ($stripped.TrimEnd() + $sep + $block + "`r`n"), $utf8NoBom)
        Write-Host "[ok] Registered hook in $startup" -ForegroundColor Green
        Write-Host "      ONE-TIME: set PythonScript Initialisation to ATSTARTUP" -ForegroundColor Yellow
        Write-Host "      (Plugins > PythonScript > Configuration...) so startup.py runs on launch." -ForegroundColor Yellow

        # --- 4b. Crate editing: pip install usd-core + write cfg ----------
        $cfg = Join-Path $psUserScripts 'OpenUSD_view.cfg'
        if ($BinaryViewer) {
            $python = $null
            $g = Get-Command python -ErrorAction SilentlyContinue
            if ($g) { $python = $g.Source }
            if (-not $python) {
                $pyl = Get-Command py -ErrorAction SilentlyContinue
                if ($pyl) { try { $python = (& py -3 -c "import sys;print(sys.executable)").Trim() } catch {} }
            }
            if (-not $python) {
                Write-Warning "No Python found on PATH; cannot enable the crate editing. Install Python 3.9-3.14 and re-run."
            } else {
                $ver = (& $python -c "import sys;print('%d.%d'%sys.version_info[:2])").Trim()
                $vp  = $ver.Split('.'); $maj=[int]$vp[0]; $min=[int]$vp[1]
                if ($maj -ne 3 -or $min -lt 9 -or $min -gt 14) {
                    Write-Warning "Python $ver is outside usd-core's supported range (3.9-3.14). Crate editing not enabled."
                } else {
                    Write-Host "[..] Installing 'usd-core' into $python (this can take a minute)..." -ForegroundColor Cyan
                    $reqs = Join-Path $here 'requirements.txt'
                    if (Test-Path $reqs) {
                        & $python -m pip install --upgrade -r $reqs
                    } else {
                        & $python -m pip install --upgrade usd-core
                    }
                    & $python -c "import pxr" 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        [System.IO.File]::WriteAllText($cfg, $python, $utf8NoBom)
                        Write-Host "[ok] usd-core ready; crate editing enabled -> $cfg" -ForegroundColor Green
                    } else {
                        Write-Warning "usd-core did not import after install; crate editing not enabled."
                    }
                }
            }
        } elseif (Test-Path $cfg) {
            Write-Host "[info] Crate editing already enabled ($cfg). Re-run with -BinaryViewer to update Python/usd-core." -ForegroundColor DarkGray
        }
    } else {
        Write-Warning "Could not install the PythonScript hook to $psUserScripts."
    }
}

Write-Host ""
Write-Host "Done. Restart Notepad++. Open a .usda file (or pick 'OpenUSD' from the Language menu)." -ForegroundColor Cyan
