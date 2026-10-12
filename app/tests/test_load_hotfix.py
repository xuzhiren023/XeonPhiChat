"""Model publication and failure evidence regressions; no real model or card."""
from __future__ import annotations

import base64
import json
from pathlib import Path

import pytest

from test_job_fixture import PWSH, setup_app, run_job, change_fixture

pytestmark = pytest.mark.skipif(not PWSH, reason="PowerShell required")


@pytest.mark.parametrize("valid", [True, False])
def test_other_download_finishes_first_is_validated_and_preserved(tmp_path: Path, valid: bool) -> None:
    f = setup_app(tmp_path)
    model = "fixture-extra"
    path = f["project"] / "models" / f["models"][model]["filename"]
    payload = path.read_bytes()
    path.unlink()
    f["env"]["HOTFIX_PAYLOAD"] = base64.b64encode(payload).decode()
    f["env"]["HOTFIX_DESTINATION"] = str(path)
    f["env"]["HOTFIX_WINNER_VALID"] = str(valid)
    # Replace only the HTTP transport boundary. The actual publish, receipt,
    # size/hash admission, card staging and job failure handlers execute.
    with (f["app"] / "lib/Transport.ps1").open("a") as file:
        file.write(r'''
function Receive-ModelDownload([uri]$Uri,[string]$Path,[long]$TotalBytes,[int]$Seconds=3600) {
    $bytes=[Convert]::FromBase64String($env:HOTFIX_PAYLOAD)
    [IO.File]::WriteAllBytes($Path,$bytes)
    if ($env:HOTFIX_WINNER_VALID -eq 'False') { $bytes[4]=$bytes[4] -bxor 1 }
    [IO.File]::WriteAllBytes($env:HOTFIX_DESTINATION,$bytes)
}
''')
    result, status, job = run_job(f, "competing-download", model, action="Load", messages=[])
    assert (result.returncode == 0) is valid, (result.stdout, result.stderr, status)
    assert path.exists() and not list(path.parent.glob("*.part"))
    if valid:
        assert status["state"] == "done" and (job / "ready.json").exists()
        assert path.read_bytes() == payload
    else:
        assert status["state"] == "failed" and not (job / "ready.json").exists()
        assert "pinned SHA-256" in status["message"]
        assert path.read_bytes() != payload, "Never overwrite the existing winner after a failed identity check"


def test_original_error_survives_status_publication_failure(tmp_path: Path) -> None:
    f = setup_app(tmp_path)
    change_fixture(f, architecture="x86_64")
    with (f["app"] / "lib/Transport.ps1").open("a") as file:
        file.write(r'''
$script:originalStatus=${function:Set-JobStatus}
function Set-JobStatus([string]$Message,[string]$State='running',$Extra=$null,$Progress=$null) {
    if ($State -eq 'failed') { throw 'fixture status file is locked' }
    & $script:originalStatus $Message $State $Extra $Progress
}
''')
    result, status, job = run_job(f, "status-lock", action="Load", messages=[])
    assert result.returncode != 0
    assert status["state"] == "running", "Fixture intentionally blocks only the final status write"
    failure = json.loads((job / "failure.json").read_text())
    assert failure["state"] == "failed" and "not K1OM" in failure["message"]
    assert failure["script_line"] > 0 and failure["stack"]
    assert "not K1OM" in (job / "failure.txt").read_text()
    assert "Status write failed" in result.stdout
    assert not (job / "ready.json").exists()


def test_cache_path_conflict_names_file_and_preserves_it(tmp_path: Path) -> None:
    import shutil

    f = setup_app(tmp_path)
    cache = f["project"] / "models"
    shutil.rmtree(cache)  # Synthetic test files only.
    cache.write_text("unrelated operator data")
    result, status, job = run_job(f, "cache-file", action="Load", messages=[])
    assert result.returncode != 0 and status["state"] == "failed"
    assert str(cache) in status["message"] and "not a directory" in status["message"]
    assert cache.read_text() == "unrelated operator data"
    assert (job / "failure.json").exists()
    assert not (f["remote"] / "tmp/knc-phase3-workload.lock").exists()
