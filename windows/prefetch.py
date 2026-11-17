"""Download everything ahead of time, then time a short transcription.

Like the Docker image, the soundfonts (~250 MB) are fetched up front; then the
chosen model is downloaded, loaded on the GPU and run on the bundled 10 s clip.
"""

import os
import sys
import time
from pathlib import Path

from muscriptor.soundfonts import SF2_URL, SF3_URL
from muscriptor.transcription_model import TranscriptionModel
from muscriptor.utils.download import ModelDownloadError, download_if_necessary

root = Path(__file__).resolve().parent.parent
model_name = os.environ.get("MUSCRIPTOR_MODEL", "large")
device = os.environ.get("MUSCRIPTOR_DEVICE", "cuda")
dtype = os.environ.get("MUSCRIPTOR_DTYPE", "float16")

print("    soundfonts ...")
for url in (SF2_URL, SF3_URL):
    print(f"      {download_if_necessary(url)}")

print(f"    model '{model_name}' on {device} ({dtype}) ...")
t0 = time.perf_counter()
try:
    model = TranscriptionModel.load_model(model_name, device=device, dtype=dtype)
except ModelDownloadError as e:
    print(f"    [x] {e}")
    sys.exit(1)
print(f"      loaded in {time.perf_counter() - t0:.1f} s")

clip = root / "web" / "public" / "headache_by_lost_deposit_10s.mp3"
if clip.is_file():
    print(f"    test transcription of {clip.name} ...")
    t0 = time.perf_counter()
    model.transcribe_and_postprocess(clip)
    print(f"      done in {time.perf_counter() - t0:.1f} s (includes CUDA warm-up)")

import torch  # noqa: E402

if torch.cuda.is_available():
    print(f"      peak VRAM: {torch.cuda.max_memory_allocated() / 2**30:.2f} GB")
