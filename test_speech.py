import json
import os
from pathlib import Path
from urllib.request import Request, urlopen
from dotenv import dotenv_values

cfg = {**dotenv_values(".env"), **os.environ}
voice = input("Voice ID [none]: ").strip() or "none"
payload = {"model": cfg.get("IRODORI_MODEL_NAME", "irodori-tts"), "input": "こんにちは。音声の生成テストです。", "voice": voice, "response_format": "wav"}
if voice == "none":
    payload["irodori"] = {"caption": "明るく自然な女性の声。"}
headers = {"Content-Type": "application/json"}
if cfg.get("IRODORI_API_KEY"):
    headers["Authorization"] = "Bearer " + cfg["IRODORI_API_KEY"]
req = Request(f"http://127.0.0.1:{cfg.get('IRODORI_PORT', '8088')}/v1/audio/speech", data=json.dumps(payload).encode(), headers=headers)
print("Generating... First run may download large model files.")
with urlopen(req, timeout=3600) as response:
    audio = response.read()
if len(audio) < 44 or audio[:4] != b"RIFF" or audio[8:12] != b"WAVE":
    raise RuntimeError("The response was not a WAV file")
out = Path(__file__).resolve().parent / "test-output.wav"
out.write_bytes(audio)
print(f"Saved: {out}")
