$InstallerModels = @(
    'Aratako/Irodori-TTS-v4-Large-Quantized/int8-weight-only',
    'Aratako/Irodori-TTS-v4.1-Small',
    'Aratako/Irodori-TTS-v4.1-Small-Quantized/int8-weight-only'
)

function Read-InstallerModel {
    Write-Host '1 = v4 Large INT8 (weight-only)'
    Write-Host '2 = v4.1-Small Original'
    Write-Host '3 = v4.1-Small INT8 (weight-only)'
    $choice = (Read-Host 'Model [1]').Trim()
    if ($choice -eq '') { $choice = '1' }
    if ($choice -notin @('1', '2', '3')) { throw 'Select 1, 2, or 3. No settings were changed.' }
    return $InstallerModels[[int]$choice - 1]
}

function Get-InstallerSetting([string]$Content, [string]$Key) {
    $pattern = '(?m)^[ \t]*(?:export[ \t]+)?' + [regex]::Escape($Key) + '[ \t]*=[ \t]*([^\r\n]*)'
    $matches = [regex]::Matches($Content, $pattern)
    if ($matches.Count -eq 0) { return '' }
    return $matches[$matches.Count - 1].Groups[1].Value.Trim().Trim('"').Trim("'")
}

function Set-InstallerModelContent([string]$Content, [string]$Model) {
    if ($Model -notin $InstallerModels) { throw 'Unsupported model. No settings were changed.' }
    $newline = "`n"
    if ($Content.Contains("`r`n")) { $newline = "`r`n" }
    foreach ($entry in @(@('IRODORI_HF_CHECKPOINT', $Model), @('IRODORI_CHECKPOINT', ''))) {
        $pattern = '(?m)^[ \t]*(?:export[ \t]+)?' + $entry[0] + '[ \t]*=[^\r\n]*'
        $replacement = $entry[0] + '=' + $entry[1]
        if ([regex]::IsMatch($Content, $pattern)) {
            $Content = [regex]::Replace($Content, $pattern, $replacement)
        } else {
            if ($Content.Length -gt 0 -and -not $Content.EndsWith("`n")) { $Content += $newline }
            $Content += $replacement + $newline
        }
    }
    return $Content
}

function Save-InstallerModel([string]$EnvPath, [string]$Model) {
    if (-not (Test-Path -LiteralPath $EnvPath -PathType Leaf)) { throw 'Run 01_Install.bat first: server/.env was not found.' }
    $original = [IO.File]::ReadAllText($EnvPath)
    $updated = Set-InstallerModelContent $original $Model
    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N')
    $backup = $EnvPath + '.before-model-' + $stamp + '.bak'
    [IO.File]::Copy($EnvPath, $backup, $false)
    [IO.File]::WriteAllText($EnvPath, $updated, (New-Object Text.UTF8Encoding($false)))
    Write-Host "Backup: $backup"
    Write-Host "Selected model: $Model"
}

function Use-InstallerModelSettings([string]$EnvPath) {
    # Use this installer's .env for model selection, including when the parent
    # process inherited a model setting from a different Irodori installation.
    $content = [IO.File]::ReadAllText($EnvPath)
    $model = Get-InstallerSetting $content 'IRODORI_HF_CHECKPOINT'
    if ($model) { $env:IRODORI_HF_CHECKPOINT = $model }
    $checkpoint = Get-InstallerSetting $content 'IRODORI_CHECKPOINT'
    if ($checkpoint) { $env:IRODORI_CHECKPOINT = $checkpoint }
    else { $env:IRODORI_CHECKPOINT = ' ' }
    Write-Host "Model: $env:IRODORI_HF_CHECKPOINT"
    if ($checkpoint) { Write-Host "Local checkpoint: $checkpoint" }
}
