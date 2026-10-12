"""Real small localhost download exercises .NET progress and cancellation."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import os
import shutil
import subprocess
import threading
import time

import pytest

ROOT=Path(__file__).resolve().parents[1]
PWSH=os.environ.get('PHI_TEST_PWSH') or shutil.which('pwsh')
pytestmark=pytest.mark.skipif(not PWSH,reason='PowerShell is required')
PAYLOAD=b'GGUF'+b'x'*(512*1024-4)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == '/http_error':
            self.send_error(503, 'fixture download unavailable')
            return
        self.send_response(200)
        self.send_header('Content-Length',str(len(PAYLOAD)))
        self.end_headers()
        try:
            for offset in range(0,len(PAYLOAD),8192):
                self.wfile.write(PAYLOAD[offset:offset+8192]);self.wfile.flush()
                time.sleep(0.04)
        except (BrokenPipeError,ConnectionResetError):
            pass

    def log_message(self, format: str, *args: object) -> None:
        pass


def psquote(path: Path) -> str:
    return "'"+str(path).replace("'","''")+"'"


def progress_rows(file: Path) -> list[dict]:
    rows=[]
    if file.exists():
        for line in file.read_text().splitlines():
            try: rows.append(json.loads(line))
            except json.JSONDecodeError: pass  # The worker may be appending a line.
    return rows


@pytest.mark.parametrize('scenario',['complete','cancel','wrong_size','stale_event','timeout','thermal','http_error'])
def test_download_reports_real_progress_and_never_marks_failure_ready(tmp_path: Path, scenario: str) -> None:
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    script=tmp_path/'download.ps1'
    expected=len(PAYLOAD)+(1 if scenario=='wrong_size' else 0)
    seconds=1 if scenario=='timeout' else 15
    script.write_text(f'''Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. {psquote(ROOT/'lib/ChatCore.ps1')}
. {psquote(ROOT/'lib/Transport.ps1')}
$script:job={psquote(tmp_path)}
$script:health=$null; $script:cleanupMode=$false
$script:request=[pscustomobject]@{{owner_pid=0}}
function Update-LoadTemperature {{
    # Inject a thermal rejection after actual network data arrives. Live micinfo
    # integration is covered separately by the job fixture.
    if ('{scenario}' -eq 'thermal' -and (Test-Path -LiteralPath {psquote(tmp_path/'model.part')})) {{
        if ((Get-Item -LiteralPath {psquote(tmp_path/'model.part')}).Length -gt 0) {{ throw 'fixture thermal limit reached' }}
    }}
}}
# Reproduce a stale progress snapshot: another consumer has already removed one
# event. The real Remove-Event cmdlet then emits the operator's missing-ID error
# in the old downloader. The replacement downloader has no PowerShell queue.
$script:staleInjected=$false
if ('{scenario}' -eq 'stale_event') {{
    function Get-Event {{
        [CmdletBinding()]
        param([string]$SourceIdentifier)
        $queued=@(Microsoft.PowerShell.Utility\\Get-Event -SourceIdentifier $SourceIdentifier -ErrorAction SilentlyContinue)
        if ($queued.Count -gt 0 -and !$script:staleInjected) {{
            Microsoft.PowerShell.Utility\\Remove-Event -EventIdentifier $queued[0].EventIdentifier
            $script:staleInjected=$true
        }}
        $queued
    }}
}}
$null=New-Event -SourceIdentifier 'fixture-unrelated'
$downloadCode=0
try {{ Receive-ModelDownload ([uri]'http://127.0.0.1:{server.server_port}/{scenario}') {psquote(tmp_path/'model.part')} {expected} {seconds} }}
catch {{ Write-Utf8 {psquote(tmp_path/'error.txt')} $_.Exception.Message; $downloadCode=1 }}
finally {{
    $queue=@(Microsoft.PowerShell.Utility\\Get-Event)
    $subscriptions=@(Get-EventSubscriber)
    Write-JsonFile {psquote(tmp_path/'event-state.json')} ([pscustomobject]@{{sources=@($queue | Select-Object -ExpandProperty SourceIdentifier);subscriptions=$subscriptions.Count}})
}}
exit $downloadCode
''')
    process=subprocess.Popen([str(PWSH),'-NoProfile','-File',str(script)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
        if scenario=='cancel':
            deadline=time.monotonic()+10
            while time.monotonic()<deadline and process.poll() is None:
                if any(0<r['bytes']<r['total_bytes'] for r in progress_rows(tmp_path/'load-progress.jsonl')):
                    (tmp_path/'cancel').write_text('stop');break
                time.sleep(0.05)
            assert (tmp_path/'cancel').exists(),'No intermediate download progress received'
        stdout,stderr=process.communicate(timeout=20)
        rows=progress_rows(tmp_path/'load-progress.jsonl')
        event_state=json.loads((tmp_path/'event-state.json').read_text())
        assert event_state=={'sources':['fixture-unrelated'],'subscriptions':0}
        if scenario not in ('thermal','http_error'):
            assert any(0<r['percent']<100 and 0<r['bytes']<len(PAYLOAD) for r in rows),(stdout,stderr,rows)
        if scenario in ('complete','stale_event'):
            assert process.returncode==0,(stdout,stderr,(tmp_path/'error.txt').read_text() if (tmp_path/'error.txt').exists() else '')
            assert (tmp_path/'model.part').read_bytes()==PAYLOAD
            assert rows[-1]['percent']==100 and rows[-1]['bytes']==len(PAYLOAD)
        else:
            assert process.returncode!=0
            assert not (tmp_path/'model.part').exists()
            assert all(r['percent']<100 for r in rows)
            message={'cancel':'Stopped by operator','wrong_size':'Incomplete model download',
                     'timeout':'Model download timed out','thermal':'fixture thermal limit reached',
                     'http_error':'503'}[scenario]
            assert message in (tmp_path/'error.txt').read_text()
    finally:
        if process.poll() is None: process.kill();process.wait(timeout=5)
        server.shutdown();server.server_close();thread.join(timeout=2)
