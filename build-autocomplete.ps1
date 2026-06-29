#requires -Version 3.0
<#
.SYNOPSIS
    Regenerates OpenUSD.autocomplete.xml from the keyword lists in OpenUSD.udl.xml.
    Run this whenever you add keywords/types/schemas to the UDL so the two stay in sync.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$udlPath = Join-Path $here 'OpenUSD.udl.xml'
$acPath  = Join-Path $here 'OpenUSD.autocomplete.xml'

[xml]$x = Get-Content -Raw $udlPath
$groups = 'Keywords1','Keywords2','Keywords3','Keywords4','Keywords5','Keywords6','Keywords7','Keywords8'
$words = foreach ($g in $groups) {
    (($x.NotepadPlus.UserLang.KeywordLists.Keywords | Where-Object { $_.name -eq $g }).'#text') -split '\s+'
}
$words = $words | Where-Object { $_ -and $_.Trim() -ne '' } | Sort-Object -Unique

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8" ?>')
[void]$sb.AppendLine('<!--')
[void]$sb.AppendLine('  OpenUSD autocompletion for Notepad++.')
[void]$sb.AppendLine('  Install: copy to  %AppData%\Notepad++\autoCompletion\OpenUSD.xml')
[void]$sb.AppendLine('  (file name MUST match the UDL language name "OpenUSD").')
[void]$sb.AppendLine('  GENERATED from OpenUSD.udl.xml keyword lists - regenerate with build-autocomplete.ps1.')
[void]$sb.AppendLine('-->')
[void]$sb.AppendLine('<NotepadPlus>')
[void]$sb.AppendLine('    <AutoComplete language="OpenUSD">')
[void]$sb.AppendLine('        <Environment ignoreCase="no" startFunc="(" stopFunc=")" paramSeparator="," terminal=";" additionalWordChar="" />')
foreach ($w in $words) { [void]$sb.AppendLine("        <KeyWord name=`"$w`" />") }
[void]$sb.AppendLine('    </AutoComplete>')
[void]$sb.AppendLine('</NotepadPlus>')

[System.IO.File]::WriteAllText($acPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[ok] Regenerated $acPath with $($words.Count) completion words." -ForegroundColor Green
