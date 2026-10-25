$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'model-settings.ps1')
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Read-Host { return $script:TestChoice }
$expected = @(
    'Aratako/Irodori-TTS-v4-Large-Quantized/int8-weight-only',
    'Aratako/Irodori-TTS-v4.1-Small',
    'Aratako/Irodori-TTS-v4.1-Small-Quantized/int8-weight-only'
)
foreach ($index in 0..2) {
    $script:TestChoice = [string]($index + 1)
    Assert ((Read-InstallerModel) -ceq $expected[$index]) "Choice $($index + 1) model ID"
}
$script:TestChoice = ''
Assert ((Read-InstallerModel) -ceq $expected[0]) 'Enter keeps Large INT8 as default'
foreach ($invalid in @('0', '4', 'abc', '-1', '1.0')) {
    $script:TestChoice = $invalid
    $failed = $false
    try { $null = Read-InstallerModel } catch { $failed = $true }
    Assert $failed "Reject invalid choice: $invalid"
}
$fixture = "# Existing config`r`nIRODORI_HF_CHECKPOINT=old`r`nIRODORI_HF_CHECKPOINT=duplicate`r`nexport IRODORI_CHECKPOINT = 'F:/old/model.safetensors'`r`nIRODORI_PORT=8089`r`nIRODORI_HOST=0.0.0.0`r`nIRODORI_API_KEY=test-value`r`nOTHER=日本語`r`n"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('irodori-model-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tempRoot
$envPath = Join-Path $tempRoot '.env'
$oldHf = $env:IRODORI_HF_CHECKPOINT
$oldLocal = $env:IRODORI_CHECKPOINT
try {
    foreach ($model in $expected) {
        [IO.File]::WriteAllText($envPath, $fixture, (New-Object Text.UTF8Encoding($false)))
        Save-InstallerModel $envPath $model
        $saved = [IO.File]::ReadAllText($envPath)
        Assert ((Get-InstallerSetting $saved 'IRODORI_HF_CHECKPOINT') -ceq $model) 'Persist selected model'
        Assert ((Get-InstallerSetting $saved 'IRODORI_CHECKPOINT') -eq '') 'Clear local checkpoint override'
        Assert ($saved.Contains("IRODORI_PORT=8089`r`nIRODORI_HOST=0.0.0.0`r`nIRODORI_API_KEY=test-value`r`nOTHER=日本語`r`n")) 'Preserve other settings and CRLF'
        Assert (-not $saved.Contains('duplicate')) 'Replace duplicate model settings'
        $env:IRODORI_HF_CHECKPOINT = 'inherited-old-model'
        $env:IRODORI_CHECKPOINT = 'F:/inherited-old/model.safetensors'
        Use-InstallerModelSettings $envPath
        Assert ($env:IRODORI_HF_CHECKPOINT -ceq $model) 'Launch uses selected model over inherited model'
        Assert ($env:IRODORI_CHECKPOINT.Trim() -eq '') 'Launch masks inherited local checkpoint'
    }
    $backups = @(Get-ChildItem -LiteralPath $tempRoot -Force -Filter '*.bak')
    Assert ($backups.Count -eq 3) 'Keep separate backups for all three changes'
    foreach ($backup in $backups) { Assert ([IO.File]::ReadAllText($backup.FullName) -ceq $fixture) 'Backup equals original config' }
    $minimal = Set-InstallerModelContent "IRODORI_PORT=8088`n" $expected[1]
    Assert ((Get-InstallerSetting $minimal 'IRODORI_HF_CHECKPOINT') -ceq $expected[1]) 'Append missing keys'
    Assert (-not $minimal.Contains("`r")) 'Preserve LF config'
    $before = [IO.File]::ReadAllBytes($envPath)
    $failed = $false
    try { Save-InstallerModel $envPath 'unsupported/model' } catch { $failed = $true }
    Assert $failed 'Reject unsupported model'
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($envPath)) -ceq [Convert]::ToBase64String($before)) 'Invalid choice never changes .env'
    $failed = $false
    try { Save-InstallerModel (Join-Path $tempRoot 'missing.env') $expected[0] } catch { $failed = $true }
    Assert $failed 'Missing installation gives error'
    $localConfig = "IRODORI_HF_CHECKPOINT=manual/model`nIRODORI_CHECKPOINT='F:/manual/model.safetensors'`n"
    [IO.File]::WriteAllText($envPath, $localConfig)
    Use-InstallerModelSettings $envPath
    Assert ($env:IRODORI_CHECKPOINT -ceq 'F:/manual/model.safetensors') 'Manual local checkpoint remains supported'
    Write-Host 'PASS: model choices, invalid input, config preservation, backups, and launch overrides.'
} finally {
    $env:IRODORI_HF_CHECKPOINT = $oldHf
    $env:IRODORI_CHECKPOINT = $oldLocal
    # Delete only this test's unique files, with no recursive directory removal.
    Get-ChildItem -LiteralPath $tempRoot -Force -File | Remove-Item -Force
    Remove-Item -LiteralPath $tempRoot
}
