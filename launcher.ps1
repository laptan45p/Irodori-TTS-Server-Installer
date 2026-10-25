param([ValidateSet('Install','Start','Diagnose','Login','Test','SelectModel')][string]$Mode='Start')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$Root=$PSScriptRoot
$App=Join-Path $Root 'server'
$Tools=Join-Path $Root 'tools'
$Uv=Join-Path $Tools 'uv\uv.exe'
$Python=Join-Path $App '.venv\Scripts\python.exe'
$Commit='61012c760f22f7b4a6c21c5c5f8f9e148120b6f9'
$env:UV_PYTHON_INSTALL_DIR=Join-Path $Tools 'python'
$env:UV_CACHE_DIR=Join-Path $Root 'cache\uv'
$env:HF_HOME=Join-Path $Root 'cache\huggingface'
$env:UV_PYTHON_PREFERENCE='only-managed'
$env:PYTHONUTF8='1'
$env:PYTHONUNBUFFERED='1'
$env:PATH="$(Join-Path $Tools 'git\cmd');$env:PATH"
$env:GIT_TERMINAL_PROMPT='0'
New-Item -ItemType Directory -Force -Path (Join-Path $Root 'logs') | Out-Null
$Logging=$false
. (Join-Path $Root 'model-settings.ps1')
function Run([string]$Exe,[string[]]$Arguments) {
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Exe failed (exit $LASTEXITCODE)." }
}
function Download([string]$Url,[string]$Dest) {
    for ($attempt=1; $attempt -le 3; $attempt++) {
        try { Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile "$Dest.part"; Move-Item -Force -LiteralPath "$Dest.part" -Destination $Dest; return }
        catch { if ($attempt -eq 3) { throw }; Write-Host "Download retry $attempt/3..." }
    }
}
function Get-Setting([string]$Key,[string]$Default) {
    $line=Get-Content -LiteralPath (Join-Path $App '.env') | Where-Object { $_ -match ('^'+[regex]::Escape($Key)+'=') } | Select-Object -Last 1
    if ($null -eq $line) { return $Default }
    return ($line.Substring($Key.Length+1)).Trim().Trim('"').Trim("'")
}
try {
    if (-not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw 'Windows x64 is required. Use 64-bit Windows PowerShell.' }
    Set-Location -LiteralPath $Root
    if ($Mode -ne 'Login') {
        Start-Transcript -Path (Join-Path $Root ("logs\{0}-{1}.log" -f $Mode,(Get-Date -Format 'yyyyMMdd-HHmmss'))) | Out-Null
        $Logging=$true
    }
    if ($Mode -eq 'SelectModel') {
        $envPath = Join-Path $App '.env'
        if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) { throw '先に 01_Install.bat を実行してください。' }
        Write-Host '先にサーバーをCtrl+Cで停止してください。切り替え後は02_Start.batで再起動します。'
        Write-Host 'LargeとSmallでは対応するSpeaker Embeddingが異なります。選んだ基盤モデルに合う声を使ってください。'
        $model = Read-InstallerModel
        Save-InstallerModel $envPath $model
        Write-Host '保存しました。02_Start.batで起動してください。' -ForegroundColor Green
    } elseif ($Mode -eq 'Install') {
        Write-Host 'Irodori-TTS-Server 簡易インストーラー' -ForegroundColor Cyan
        Write-Host 'このフォルダへ専用Python/Git/uvを導入します。インターネットと十分な空き容量が必要です。'
        $backend=Read-Host '実行環境: 1=NVIDIA GPU / 2=CPU（低速） [1]'
        if ($backend -eq '' -or $backend -eq '1') { $backend='cu128' } elseif ($backend -eq '2') { $backend='cpu' } else { throw '1 または 2 を指定してください。' }
        if ($backend -eq 'cu128') {
            if (-not (Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue)) { throw 'NVIDIAドライバーが見つかりません。ドライバーをインストールして再実行してください。' }
            Run 'nvidia-smi.exe' @('--query-gpu=name,driver_version,memory.total','--format=csv')
        }
        $model='Aratako/Irodori-TTS-v4-Large-Quantized/int8-weight-only'
        $bind='0.0.0.0'
        if (-not (Test-Path -LiteralPath (Join-Path $App '.env'))) {
            $model=Read-InstallerModel
            $network=Read-Host '接続: 1=同じLANの別PCから利用 / 2=このPCだけ [1]'
            if ($network -eq '2') { $bind='127.0.0.1' } elseif ($network -notin @('','1')) { throw '1 または 2 を指定してください。' }
        } else { Write-Host '既存の .env と音声データを保持します。モデル変更は 06_Select_Model.bat で行えます。' }
        New-Item -ItemType Directory -Force -Path $Tools | Out-Null
        if (-not (Test-Path -LiteralPath $Uv)) {
            Write-Host 'uv をダウンロードしています...'
            Download 'https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip' (Join-Path $Tools 'uv.zip')
            Expand-Archive -LiteralPath (Join-Path $Tools 'uv.zip') -DestinationPath (Join-Path $Tools 'uv') -Force
        }
        if (-not (Test-Path -LiteralPath (Join-Path $Tools 'git\cmd\git.exe'))) {
            Write-Host 'Portable MinGit をダウンロードしています...'
            $release=Invoke-RestMethod -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest'
            $asset=@($release.assets | Where-Object { $_.name -match '^MinGit-[0-9]+(?:\.[0-9]+)*-64-bit\.zip$' })
            if ($asset.Count -ne 1) {
                $names=(@($release.assets | Where-Object { $_.name -like 'MinGit-*' } | ForEach-Object { $_.name }) -join ', ')
                throw ("通常版MinGit x64を特定できません。Release: {0}; Candidates: {1}" -f $release.tag_name,$names)
            }
            Write-Host ("選択したMinGit: {0}" -f $asset[0].name)
            Download $asset[0].browser_download_url (Join-Path $Tools 'git.zip')
            Expand-Archive -LiteralPath (Join-Path $Tools 'git.zip') -DestinationPath (Join-Path $Tools 'git') -Force
        }
        Run $Uv @('--version')
        Run (Join-Path $Tools 'git\cmd\git.exe') @('--version')
        if (-not (Test-Path -LiteralPath $App)) {
            Write-Host '公式サーバーをダウンロードしています...'
            Download "https://github.com/Aratako/Irodori-TTS-Server/archive/$Commit.zip" (Join-Path $Tools 'server.zip')
            $stage=Join-Path $Tools ('source-'+[guid]::NewGuid().ToString('N'))
            Expand-Archive -LiteralPath (Join-Path $Tools 'server.zip') -DestinationPath $stage
            Move-Item -LiteralPath (Join-Path $stage "Irodori-TTS-Server-$Commit") -Destination $App
            Remove-Item -LiteralPath $stage
            [IO.File]::WriteAllText((Join-Path $App 'INSTALLER_SOURCE_COMMIT.txt'),$Commit)
        }
        if (-not (Test-Path -LiteralPath (Join-Path $App 'pyproject.toml'))) { throw 'serverフォルダが不完全です。既存データを退避してから再導入してください。' }
        Set-Location -LiteralPath $App
        Run $Uv @('python','install','3.10')
        Run $Uv @('sync','--locked','--python','3.10','--extra',$backend)
        if (-not (Test-Path -LiteralPath '.env')) {
            $config=[IO.File]::ReadAllText((Join-Path $App '.env.example'))
            $config=$config -replace '(?m)^IRODORI_HF_CHECKPOINT=.*$',("IRODORI_HF_CHECKPOINT="+$model)
            $config=$config -replace '(?m)^IRODORI_HOST=.*$',("IRODORI_HOST="+$bind)
            $config=$config -replace '(?m)^IRODORI_TTS_BACKEND=.*$',("IRODORI_TTS_BACKEND="+$backend)
            if ($backend -eq 'cu128') { $config=$config -replace '(?m)^IRODORI_MODEL_PRECISION=.*$','IRODORI_MODEL_PRECISION=bf16' }
            $config=$config -replace '(?m)^IRODORI_MODEL_LOAD_TIMEOUT=.*$','IRODORI_MODEL_LOAD_TIMEOUT=1800'
            [IO.File]::WriteAllText((Join-Path $App '.env'),$config,(New-Object Text.UTF8Encoding($false)))
        }
        Run $Python @((Join-Path $Root 'check_environment.py'))
        if ($backend -eq 'cu128') {
            Run $Python @((Join-Path $Root 'check_environment.py'),'--require-cuda')
        }
        [IO.File]::WriteAllText((Join-Path $Root 'installed-backend.txt'),$backend)
        Write-Host 'インストール完了！ 02_Start.bat で起動してください。モデルは初回の音声生成時にダウンロードします。' -ForegroundColor Green
    } else {
        if (-not (Test-Path -LiteralPath $Python)) { throw '先に 01_Install.bat を実行してください。' }
        Set-Location -LiteralPath $App
        if ($Mode -eq 'Start') {
            if (-not (Test-Path -LiteralPath (Join-Path $Root 'installed-backend.txt'))) { throw 'インストールが未完了です。01_Install.bat を再実行してください。' }
            Use-InstallerModelSettings (Join-Path $App '.env')
            $port=Get-Setting 'IRODORI_PORT' '8088'
            Write-Host "接続確認: http://127.0.0.1:$port/health"
            Write-Host "別PCの接続先: http://<このPCのIPv4アドレス>:$port/v1"
            Write-Host '初回の音声生成はモデルのダウンロードで時間がかかります。停止: Ctrl+C'
            Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } | ForEach-Object { Write-Host ("LAN候補: http://{0}:{1}/v1" -f $_.IPAddress,$port) }
            Run $Python @('-m','irodori_openai_tts')
        } elseif ($Mode -eq 'Login') {
            Run $Python @((Join-Path $Root 'hf_login.py'))
        } elseif ($Mode -eq 'Test') {
            Run $Python @((Join-Path $Root 'test_speech.py'))
        } else {
            Run $Python @((Join-Path $Root 'check_environment.py'))
            $port=Get-Setting 'IRODORI_PORT' '8088'
            $headers=@{}
            $apiKey=Get-Setting 'IRODORI_API_KEY' ''
            if ($apiKey) { $headers.Authorization="Bearer $apiKey" }
            $response=Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$port/health" -Headers $headers -TimeoutSec 10
            Write-Host "Health HTTP status: $($response.StatusCode)"
            Write-Host 'health成功は音声生成成功を意味しません。05_Test_Speech.bat で実際に生成してください。'
        }
    }
} catch {
    Write-Host ("ERROR: "+$_.Exception.Message) -ForegroundColor Red
    if ($Logging) { Stop-Transcript | Out-Null }
    exit 1
}
if ($Logging) { Stop-Transcript | Out-Null }
exit 0
