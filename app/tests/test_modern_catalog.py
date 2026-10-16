"""Model admission tests; no model execution or native hardware is simulated."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import pytest
from test_job_fixture import ROOT, PWSH


@pytest.mark.skipif(not PWSH, reason="PowerShell required")
@pytest.mark.parametrize("model", ["huihui-step3-vl-10b-abliterated-q5_k_m"])
@pytest.mark.parametrize("action", ["Load", "Chat"])
def test_modern_worker_stops_before_card_and_download(tmp_path: Path, model: str, action: str) -> None:
    app = tmp_path / "app"
    shutil.copytree(ROOT, app, ignore=shutil.ignore_patterns("data", "__pycache__", ".pytest_cache"))
    job = tmp_path / "job"
    job.mkdir()
    # Deliberately absent keys/SSH/MPSS: compatibility must be rejected first.
    (app / "config/connection.yaml").write_text(json.dumps({"data_dir": str(tmp_path / "data")}))
    (job / "request.json").write_text(json.dumps(dict(action=action, model=model, batch=128, owner_pid=0,
                                                    ready={"model_id": model, "native_acceptance": True})))
    result = subprocess.run([str(PWSH), "-NoProfile", "-File", str(app / "Invoke-PhiJob.ps1"),
                             "-JobDir", str(job)], capture_output=True, text=True, timeout=30,
                            env=dict(os.environ, DOTNET_PROCESSOR_COUNT="2"))
    assert result.returncode == 1, result.stdout + result.stderr
    status = json.loads((job / "status.json").read_text(encoding="utf-8-sig"))
    assert "modern native KNC runtime" in status["message"]
    assert not (job / "ready.json").exists()
    assert not (tmp_path / "data").exists()
