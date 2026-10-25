# Irodori-TTS-Server-Installer v1.1.0

Windows用の非公式Irodori-TTS-Server簡易インストーラーです。

## モデル選択

| 選択 | モデル | Hugging Face ID |
|---|---|---|
| 1（既定） | v4 Large INT8 | `Aratako/Irodori-TTS-v4-Large-Quantized/int8-weight-only` |
| 2 | v4.1-Small オリジナル | `Aratako/Irodori-TTS-v4.1-Small` |
| 3 | v4.1-Small INT8 | `Aratako/Irodori-TTS-v4.1-Small-Quantized/int8-weight-only` |

## はじめかた

1. リポジトリをZIPでダウンロードし、すべて展開します。
2. `01_Install.bat` で環境・モデル・接続方法を選びます。
3. `02_Start.bat` でサーバーを起動します。
4. `05_Test_Speech.bat` で音声生成を確認します。

## 導入済み環境の更新・モデル変更

1. サーバーをCtrl+Cで停止します。
2. 最新のファイルを既存Installerフォルダーへ上書きします。`server`・`tools`・`cache` は残します。
3. **`06_Select_Model.bat`** を実行し、1〜3から選びます。
4. `02_Start.bat` で再起動します。

変更前の `.env` は `server/.env.before-model-日時-ID.bak` に自動バックアップします。
モデル以外の設定と音声ファイルは保持します。古いローカルチェックポイント指定は解除します。
起動時は、この環境の `.env` に保存したモデル指定を使います。
`01_Install.bat` の再実行では既存のモデル設定を保持します。

LargeとSmallでは対応するSpeaker Embeddingが異なります。基盤モデルに合う音声を選んでください。
Companion側のURLを変更する必要はありません。

詳細は [README.txt](README.txt) を参照してください。

## 検証

PowerShellで `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/model-selection.tests.ps1` を実行できます。
3種類の選択、不正入力、設定保存とバックアップ、起動時のモデル指定を確認します。
モデルのダウンロードとGPUでの音声生成は未検証です。

## 由来

v1.0.1の提供ZIPをベースにモデル選択を追加しています。
元ZIPのSHA-256: `46cd5e0d1d2ca2d937f471e6ccb41a5ce30f81d960974d95aaefadee470c9ce9`

公式サーバー: https://github.com/Aratako/Irodori-TTS-Server
