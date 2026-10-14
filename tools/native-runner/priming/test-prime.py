#!/usr/bin/env python3
"""Synthetic x86 reference checks, never K1OM hardware acceptance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import threading
import time
import uuid


def read_frames(pipe, output):
    try:
        while True:
            line = pipe.readline(130)
            if not line:
                raise RuntimeError("resident pipe closed")
            magic, identity, kind, length = line.decode("ascii").strip().split(" ")
            assert magic == "PHIP1" and len(identity) == 32
            length = int(length)
            assert 0 <= length <= 32768
            data = bytearray()
            while len(data) < length:
                piece = pipe.read(length - len(data))
                assert piece, "truncated frame"
                data.extend(piece)
            output.put((identity, kind, bytes(data)))
    except Exception as error:
        output.put(error)


class Resident:
    def __init__(self, command, directory):
        self.directory = directory
        (directory / "inputs").mkdir(parents=True)
        self.log = (directory / "stderr.txt").open("wb")
        self.process = subprocess.Popen(command + ["--serve", str(directory), "-n", "0"],
                                        stdout=subprocess.PIPE, stderr=self.log, bufsize=0)
        self.frames = queue.Queue()
        self.reader = threading.Thread(target=read_frames, args=(self.process.stdout, self.frames), daemon=True)
        self.reader.start()
        identity, kind, data = self.next()
        assert identity == "0" * 32 and kind == "READY"
        self.ready = json.loads(data)

    def next(self):
        value = self.frames.get(timeout=180)
        if isinstance(value, Exception):
            raise value
        return value

    def request(self, text, images=(), predict=8):
        identity = uuid.uuid4().hex
        folder = self.directory / "inputs" / identity
        folder.mkdir()
        (folder / "prompt.txt").write_bytes(text)
        for i, image in enumerate(images):
            shutil.copyfile(image, folder / ("image-%d.png" % i))
        pending = self.directory / "request.pending"
        pending.write_text("PHI_PRIME_V1\n%s\n%d\n%d\n" % (identity, predict, len(images)))
        started = time.monotonic()
        pending.rename(self.directory / "request")
        result = dict(text=bytearray(), stages=[], counts=[])
        while True:
            received, kind, data = self.next()
            assert received == identity, "cross-request output"
            if kind == "TEXT":
                result["text"].extend(data)
            elif kind == "STAGE":
                result["stages"].append(data.decode())
            elif kind == "COUNT":
                result["counts"].append(int(data))
            elif kind == "ACK":
                result["ack_ms"] = 1000 * (time.monotonic() - started)
            elif kind in ("DONE", "REJECTED", "ACCEPTED"):
                result[kind.lower()] = json.loads(data)
            else:
                raise AssertionError(kind)
            if kind in ("DONE", "REJECTED"):
                # REJECTED is emitted just before request file cleanup.
                for _ in range(100):
                    if not folder.exists():
                        break
                    time.sleep(.01)
                assert not folder.exists(), "prompt/image files retained"
                result["text"] = bytes(result["text"])
                return result

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
        self.process.wait(timeout=10)
        self.process.stdout.close()
        self.log.close()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--runner", required=True, type=Path)
    p.add_argument("--fixtures", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    a = p.parse_args()
    a.output.mkdir()
    evidence = dict(kind="synthetic_x86_reference_only", hardware_acceptance=False,
                    runner_sha256=hashlib.sha256(a.runner.read_bytes()).hexdigest(), cases=[])
    env = os.environ.copy()
    env["OMP_NUM_THREADS"] = "2"
    os.environ.update(env)
    text = (a.fixtures / "text.txt").read_bytes()
    variants = [(arch, quant) for arch in ("llama", "lfm2", "lfm2moe", "qwen3")
                for quant in ("Q3_K_M", "Q4_K_M", "Q5_K_M")]
    variants.append(("qwen3", "f32"))
    for arch, quant in variants:
        name = arch + "-" + quant
        root = a.output / name
        root.mkdir()
        command = [str(a.runner), "-m", str(a.fixtures / (name + ".gguf")),
                   "-c", "512", "-b", "32", "-t", "2", "-tb", "2"]
        vision = quant == "f32"
        if vision:
            command += ["--mmproj", str(a.fixtures / "step3vl-mmproj.gguf")]
        resident = Resident(command, root / "resident")
        try:
            # Same first/third input, unrelated second input: recurrent and attention state must reset.
            first = resident.request(text)
            resident.request(b"A different conversation. Blue green yellow.")
            again = resident.request(text)
            assert first["text"] == again["text"], "previous request contaminated model state"
            fresh_command = command[:]
            if vision:
                fresh_command = fresh_command[:-2]
            fresh = subprocess.run(fresh_command + ["-f", str(a.fixtures / "text.txt"), "-n", "8"],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180, check=True)
            (root / "fresh-stderr.txt").write_bytes(fresh.stderr)
            assert first["text"] == fresh.stdout, "resident/fresh greedy output differs"
            assert "prefill" in first["stages"] and first["counts"], "no prompt progress"
            rejected = resident.request(b"token " * 1500)
            assert "rejected" in rejected and not rejected["text"]
            assert resident.request(text)["text"] == first["text"], "rejected input poisoned resident"
            if vision:
                image_prompt = (a.fixtures / "image.txt").read_bytes()
                red = resident.request(image_prompt, [a.fixtures / "red.png"])
                resident.request(image_prompt, [a.fixtures / "blue.png"])
                red_again = resident.request(image_prompt, [a.fixtures / "red.png"])
                assert red["text"] == red_again["text"] and "vision" in red["stages"]
                fresh_image = subprocess.run(command + ["-f", str(a.fixtures / "image.txt"),
                    "--image", str(a.fixtures / "red.png"), "-n", "8"],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180, check=True)
                assert red["text"] == fresh_image.stdout, "resident/fresh image output differs"
                assert resident.request(text)["text"] == first["text"], "image state leaked into text"
            rss = [resident.request(text)["done"]["rss_kib"] for _ in range(5)]
            assert max(rss) - min(rss) < 8192, "resident request memory does not stabilize"
            if name == "llama-Q5_K_M":
                auto = resident.request(text, predict=0)
                budget = auto["accepted"]
                assert budget["output_tokens"] == 512 - max(budget["prompt_tokens"], budget["prompt_positions"]) - 64
            evidence["cases"].append(dict(model=name, result="pass", vision=vision,
                ready=resident.ready, rss_kib=rss, ack_ms=first["ack_ms"],
                output_sha256=hashlib.sha256(first["text"]).hexdigest()))
            print("PASS", name, "warm/fresh, isolation, rejection, dynamic allocation, memory", flush=True)
        finally:
            resident.close()
    (a.output / "result.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print("PASS: synthetic resident checks; no Phi hardware acceptance", flush=True)


if __name__ == "__main__":
    main()
