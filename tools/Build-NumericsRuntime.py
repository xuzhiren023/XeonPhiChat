#!/usr/bin/env python3
"""Build the optional 7120P numerical-qualification runtime from pinned local inputs."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import struct
import tarfile

SOURCE = "61e97998bf49c2d425563920b7e83e52b5ae57a6"
PARENT = "69fdb3e5dea8d6b8f66125c481058180a434cee41e4081a69ffb7a20cb023ff4"
RUNNER = "e3366b50052818a7cc223f57b7b69f55316e5cd93e3ca9b67b413a849b235d54"
ROOT = Path(__file__).resolve().parent.parent


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--parent", type=Path, required=True)
    p.add_argument("--candidate", type=Path, required=True)
    p.add_argument("--projector", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    parent = a.parent.read_bytes()
    if digest(parent) != PARENT:
        raise ValueError("Parent archive changed")
    files, modes = {}, {}
    with tarfile.open(fileobj=io.BytesIO(parent)) as archive:
        for member in archive:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts or "\\" in member.name or ":" in member.name or not (member.isdir() or member.isfile()):
                raise ValueError("Unsafe member")
            if member.isfile():
                if member.name.startswith(("shared/bin/", "shared/lib/")):
                    continue
                if member.name in files:
                    raise ValueError("Duplicate member")
                files[member.name] = archive.extractfile(member).read()
                modes[member.name] = member.mode & 0o777
    manifest = json.loads((a.candidate / "manifest.json").read_text())
    if manifest["files"]["bin/llama-knc-runner"] != RUNNER or manifest["base_commit"] != SOURCE:
        raise ValueError("Candidate identity changed")
    for name, pin in manifest["files"].items():
        data = (a.candidate / name).read_bytes()
        if digest(data) != pin or data[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", data, 18)[0] != 181:
            raise ValueError("Candidate K1OM input changed: " + name)
        target = "shared/" + name.replace("bin/llama-knc-runner", "bin/phi-modern")
        files[target], modes[target] = data, 0o700
    files["shared/tests/step3vl-mmproj.gguf"] = a.projector.read_bytes()
    if digest(files["shared/tests/step3vl-mmproj.gguf"]) != "06fcb51403edb54448a9d0fb8c8aa8817a4dc73c0b658ac4dc3c96995e86e10c":
        raise ValueError("Projector regression fixture changed")
    inputs = {"source": SOURCE, "patch_sha256": manifest["patch_sha256"], "parent_sha256": PARENT,
              "files": {n: digest(d) for n, d in sorted(files.items()) if n.startswith("shared/")}}
    identity = "phichat142-modern-" + digest(encoded(inputs))[:16]
    files["shared/provenance.json"] = encoded({**inputs, "runtime_id": identity, "runner_sha256": RUNNER,
        "scope": "7120P only; native numerical replay, small fixtures and TinyDolphin; no trained vision quality claim",
        "diagnostic_callbacks": False, "rounding_overrides": False})
    for name in ("runtime-id.txt", "shared-runtime-id.txt"):
        files[name] = (identity + "\n").encode()
    files["modern-source.txt"] = (SOURCE + "\n").encode()
    a.output.mkdir(parents=True, exist_ok=False)
    target = a.output / "runtime-7120P.tar"
    with tarfile.open(target, "x", format=tarfile.USTAR_FORMAT) as archive:
        for name, data in sorted(files.items()):
            member = tarfile.TarInfo(name)
            member.size, member.mode = len(data), modes.get(name, 0o600)
            archive.addfile(member, io.BytesIO(data))
    with tarfile.open(target) as archive:
        if len(archive.getmembers()) != len(files):
            raise ValueError("Readback count")
        for member in archive:
            if archive.extractfile(member).read() != files[member.name]:
                raise ValueError("Readback content")
    if target.stat().st_size > 100 * 1024 * 1024:
        raise ValueError("Archive admission bound")
    payload = {"profile": "xeon-phi-7120p", "file": target.name, "bytes": target.stat().st_size,
        "sha256": digest(target.read_bytes()), "main_sha256": RUNNER, "runtime_id": identity,
        "compatible_model_source_commits": ["d57e0e6e4882445bc625aaee47f91db469f9fc22"],
        "features": ["auto-resources-v1", "shared-multi-quant-v1", "knc-text-image-r1"]}
    pin = {"version": "1.4.2", "source_commit": "03a8b80c7d502797325788f604248dd4aabdf5ef",
        "kernel_version": "0.2.1", "modern_source_commit": SOURCE, "payloads": [payload]}
    (ROOT / "app/config/modern-runtime-numerics-r3.json").write_bytes(encoded(pin))
    (a.output / "manifest.json").write_bytes(encoded(pin))
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
