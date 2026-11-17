"""Exit 0 only if this venv's PyTorch can actually run on the NVIDIA GPU."""

import sys

try:
    import torch
    import torchaudio  # noqa: F401  (beat-this needs it, and it must match torch)
except Exception as e:  # noqa: BLE001
    print(f"    [x] cannot import torch/torchaudio: {e}")
    sys.exit(1)

print(f"    torch {torch.__version__}, CUDA runtime {torch.version.cuda}")
if not torch.cuda.is_available():
    print("    [x] torch.cuda.is_available() is False (CPU build, or the NVIDIA driver is too old for it)")
    sys.exit(1)

props = torch.cuda.get_device_properties(0)
arch = f"sm_{props.major}{props.minor}"
print(f"    GPU: {props.name}, {props.total_memory / 2**30:.1f} GB, {arch}")
if arch not in torch.cuda.get_arch_list():
    print(f"    [x] this torch build has no kernels for {arch}: {torch.cuda.get_arch_list()}")
    sys.exit(1)

try:
    x = torch.randn(2048, 2048, device="cuda", dtype=torch.float16)
    (x @ x).float().sum().item()
    torch.cuda.synchronize()
except Exception as e:  # noqa: BLE001
    print(f"    [x] test fp16 matmul on the GPU failed: {e}")
    sys.exit(1)
print("    fp16 matmul on the GPU: OK")
