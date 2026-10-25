import sys
import torch
import torchaudio
import irodori_openai_tts
print(sys.version)
print("PyTorch:", torch.__version__)
print("CUDA:", torch.cuda.is_available())
print("GPU:", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU")
if "--require-cuda" in sys.argv:
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA unavailable: update the NVIDIA driver")
    print("CUDA computation:", (torch.ones(1, device="cuda") + 1).item())
