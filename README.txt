Irodori-TTS-Server 簡易インストーラー v1.0.1

Windows 10/11 x64用。NVIDIA GPU（CUDA 12.8）またはCPU。
これは非公式の導入補助ツールです。サーバー本体は公式からダウンロードします。
サーバー単体を導入します。CompanionやGradio画面は含みません。

■ はじめかた
1. ZIPを全て展開。例: D:\Irodori-Server
   書き込み可能な短いパスを推奨。Program Files/OneDrive配下は避けてください。
2. 01_Install.bat をダブルクリック。
   NVIDIA / CPU、モデル、LAN利用 / このPCのみ を選びます。
   初期選択: NVIDIA、v4 Large int8、LAN利用。
3. 02_Start.bat をダブルクリック。ウィンドウを開いたまま使います。
4. 同じPCで http://127.0.0.1:8088/health を開いて接続を確認。
5. 05_Test_Speech.bat で音声生成を確認。test-output.wav が作られます。
   v4 Largeで参照音声が必要な場合は下記のvoicesにWAVを置き、Voice IDを指定。
   初回生成ではモデル/コーデック等を取得するため長く待つ場合があります。

■ 自動で用意するもの
専用uv、Portable MinGit、Python 3.10、仮想環境、公式サーバーと依存関係。
PythonやGitの事前導入、管理者権限、CUDA Toolkitの個別導入は原則不要です。
NVIDIAドライバーは別途必要です。CUDAの確認に失敗したらドライバーを更新。
CPUは動作確認向けで、実用速度は保証しません。Windows AMD GPUには非対応。
インターネット接続が必須。モデル込みで数十GBの空き容量を用意してください。
オフラインインストーラーではありません。配布元の障害/変更で導入が失敗する場合があります。

■ 別PCのCompanion等から使う
サーバー起動時に「LAN候補」としてIPv4付きのURLを表示します。
例: http://192.168.1.20:8088/v1
OpenAI互換APIのBase URL欄には上記を入力。
音声エンドポイント全体を求める欄の場合: http://192.168.1.20:8088/v1/audio/speech
モデル名: irodori-tts
相手PCのlocalhostでは接続できません。サーバーPCのIPv4アドレスを使います。
両PCを同じLANにつなぎ、Windowsファイアウォールの確認はプライベートのみ許可。
つながらない場合はサーバーPCで受信TCP 8088をプライベート/ローカルサブネットに限定して許可。
このツールはファイアウォールやルーター設定を自動変更しません。
初期設定は認証なしです。外部公開やポート転送は行わないでください。
認証を有効にする場合は server\.env に IRODORI_API_KEY=任意のキー を設定し、
クライアントにも同じキーを指定してサーバーを再起動します。

■ 音声・学習した話者
server\voices に sample.wav を置くと Voice ID は sample になります。
学習した .speaker.safetensors も配置可能。対応する基盤モデルを選んでください。
話者一覧は http://127.0.0.1:8088/v1/audio/voices で確認できます。
初期モデルは Aratako/Irodori-TTS-v4-Large-Quantized/int8-weight-only。
Smallなど別のモデルへ変更すると、Largeで学習した話者が使えるとは限りません。
元PCの声・設定・モデルは自動転送しません。必要な音声ファイルをコピーしてください。

■ 設定変更
server\.env をメモ帳で編集し、02_Start.bat を起動し直します。
IRODORI_HF_CHECKPOINT : モデルID（owner/repository[/subfolder]）
IRODORI_HOST : LAN=0.0.0.0 / このPCだけ=127.0.0.1
IRODORI_PORT : ポート（既定8088）
IRODORI_MODEL_PRECISION : NVIDIA導入時bf16 / CPU導入時fp32
古いGPUでbf16非対応の場合はfp32へ変更。ただしメモリ使用量が増えます。
IRODORI_CODEC_PRECISION : fp32（公式既定）
IRODORI_PRELOAD : trueにすると起動時にモデルを読み込みます。
ローカルモデルは IRODORI_CHECKPOINT=C:/models/model.safetensors を追加。
tokenizerフォルダ等の必要な付属ファイルも公式の案内に従って配置してください。
01_Install.bat再実行では既存.env/voicesを保持します。
GPUとCPUを切り替える際は.envのdevice/precision設定も手動で見直してください。
環境変数にIRODORI_*を別途設定している場合は.envより優先されます。

■ エラー時
logsにインストール/起動/診断ログを保存します。
03_Diagnose.bat は、02_Start.batを起動した状態で実行します。
health成功はモデルの読み込み・音声生成成功とは別です。05で生成まで確認してください。
Hugging Faceの401/403が出る場合: 対象モデルの利用条件への同意を確認し、
04_HF_Login.batでreadトークンを入力。入力は非表示、ログも残しません。
認証情報はこのフォルダのcacheに保存されるため、インストール後のフォルダは他人へ配布しないでください。
トークン入力中にWindows Terminalを使う場合も画面共有に注意してください。
DLLエラー時はMicrosoft Visual C++ Redistributable x64の導入を確認。
MP3/AAC等でFFmpegが必要な場合は別途導入してPATHに追加。標準のWAVを推奨。
音声参照もWAVを推奨します。
モデル取得中にクライアントがタイムアウトする場合は、先に05で生成してから接続。
再試行は01_Install.bat。途中で失敗しても既存設定や音声は削除しません。
再実行中はサーバーを停止してください。

■ 配置と削除
server: サーバー、専用仮想環境、.env、voices
cache: モデル、ダウンロードキャッシュ、HF認証情報
tools: 専用Python/Git/uv
logs: ログ
導入後のフォルダ移動/コピーは仮想環境の絶対パスを壊す可能性があります。
別PCではこのZIPから新規インストールしてください。
アンインストールはサーバーを停止し、必要なvoices/.envを退避してフォルダ全体を削除。

■ v1.0.1 修正内容と再実行方法
MinGitの通常版とbusybox版が両方一致して停止する不具合を修正。
ZIP内のファイルを既存のインストーラーフォルダへ上書きし、01_Install.batを再実行してください。
tools、cache、serverフォルダを削除する必要はありません。
導入済みuv/Git、既存のserver/.env、音声データは保持します。

■ ソース・検証範囲
公式: https://github.com/Aratako/Irodori-TTS-Server
導入するサーバーcommit: 61012c760f22f7b4a6c21c5c5f8f9e148120b6f9
uv sync --locked --extra cu128 または cpu を使用。
本体の自動更新は行いません。uv/MinGitはインストール時の最新配布を取得。
サーバーはMIT。各モデル・依存ライブラリはそれぞれのライセンスに従ってください。
作成環境ではWindows/NVIDIAでの導入・実音声生成は未検証です。
公式コードとの設定整合性、補助Pythonの構文、ZIP内容を確認しています。
