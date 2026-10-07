#!/usr/bin/env python3
"""Download and verify local model resources required by Gridline skills."""

from __future__ import annotations

import hashlib
import os
import shutil
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parent
MODEL_ROOT = SKILL_ROOT / "resources" / "models"
WHISPER_REVISION = "eb52dbc58f50f19eb8c87b54b7c621633c67b7e0"
ASSETS = (
    (
        "Whisper Small MLX weights",
        MODEL_ROOT / "whisper-small-mlx" / "weights.npz",
        f"https://huggingface.co/mlx-community/whisper-small-mlx/resolve/{WHISPER_REVISION}/weights.npz?download=true",
        "55b6674c9b339702d486e2b1573839a66f8ec8f821ed2886993ef717a86b09f5",
    ),
    (
        "speaker segmentation model",
        MODEL_ROOT / "speaker-diarization" / "segmentation" / "model.onnx",
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2",
        "220ad67ca923bef2fa91f2390c786097bf305bceb5e261d4af67b38e938e1079",
    ),
    (
        "speaker embedding model",
        MODEL_ROOT / "speaker-diarization" / "speaker-embedding" / "model.onnx",
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx",
        "1a331345f04805badbb495c775a6ddffcdd1a732567d5ec8b3d5749e3c7a5e4b",
    ),
)
WHISPER_CONFIG = (
    MODEL_ROOT / "whisper-small-mlx" / "config.json",
    f"https://huggingface.co/mlx-community/whisper-small-mlx/resolve/{WHISPER_REVISION}/config.json?download=true",
    "e8f58e638208af66d5d5d67801259dc7a12d199e971967a9f9d33a8e3635668e",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def is_valid(path: Path, expected: str) -> bool:
    return path.is_file() and sha256(path) == expected


def fetch(url: str, destination: Path, expected_sha256: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_name(destination.name + ".download")
    digest = hashlib.sha256()
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "Gridline-model-resource-setup/1.0"})
        with urllib.request.urlopen(request, timeout=60) as response, partial.open("wb") as output:
            total = int(response.headers.get("Content-Length", "0"))
            received = 0
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    break
                output.write(block)
                digest.update(block)
                received += len(block)
                if total:
                    percent = min(100, received * 100 // total)
                    print(f"    {percent:3d}%", end="\r", flush=True)
            output.flush()
            os.fsync(output.fileno())
        print("    Download complete.        ", flush=True)
        actual = digest.hexdigest()
        if actual != expected_sha256:
            raise RuntimeError(f"SHA-256 mismatch for {destination.name}: expected {expected_sha256}, received {actual}")
        partial.replace(destination)
    finally:
        partial.unlink(missing_ok=True)


def download_segmentation_archive(destination: Path, url: str, expected_sha256: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="gridline-model-") as temporary_directory:
        archive_path = Path(temporary_directory) / "segmentation.tar.bz2"
        request = urllib.request.Request(url, headers={"User-Agent": "Gridline-model-resource-setup/1.0"})
        print("  Downloading segmentation model archive…", flush=True)
        with urllib.request.urlopen(request, timeout=60) as response, archive_path.open("wb") as output:
            shutil.copyfileobj(response, output, length=1024 * 1024)
        with tarfile.open(archive_path, mode="r:bz2") as archive:
            member = next((item for item in archive.getmembers() if Path(item.name).name == "model.onnx" and item.isfile()), None)
            if member is None or member.size > 25 * 1024 * 1024:
                raise RuntimeError("The segmentation archive did not contain the expected model.onnx file")
            source = archive.extractfile(member)
            if source is None:
                raise RuntimeError("Could not read model.onnx from the segmentation archive")
            partial = destination.with_name(destination.name + ".download")
            digest = hashlib.sha256()
            try:
                with source, partial.open("wb") as output:
                    while block := source.read(1024 * 1024):
                        output.write(block)
                        digest.update(block)
                    output.flush()
                    os.fsync(output.fileno())
                actual = digest.hexdigest()
                if actual != expected_sha256:
                    raise RuntimeError(f"SHA-256 mismatch for {destination.name}: expected {expected_sha256}, received {actual}")
                partial.replace(destination)
            finally:
                partial.unlink(missing_ok=True)


def main() -> int:
    MODEL_ROOT.mkdir(parents=True, exist_ok=True)
    config_path, config_url, config_sha = WHISPER_CONFIG
    missing = not is_valid(config_path, config_sha) or any(
        not is_valid(path, expected) for _, path, _, expected in ASSETS
    )
    if not missing:
        print(f"Model resources are ready: {MODEL_ROOT}")
        return 0

    print(f"Downloading models for resources into {MODEL_ROOT}", flush=True)
    try:
        if not is_valid(config_path, config_sha):
            print("  Downloading Whisper model configuration…", flush=True)
            fetch(config_url, config_path, config_sha)
        for label, path, url, expected in ASSETS:
            if is_valid(path, expected):
                print(f"  Already present: {label}", flush=True)
                continue
            if label == "speaker segmentation model":
                download_segmentation_archive(path, url, expected)
            else:
                print(f"  Downloading {label}…", flush=True)
                fetch(url, path, expected)
        print("All model resources are downloaded and verified.", flush=True)
        return 0
    except Exception as error:
        print(f"Model resource download failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
