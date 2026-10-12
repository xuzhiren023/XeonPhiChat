"""Host and native guard must agree on usable memory, especially RAM-backed files."""
from pathlib import Path
import json
import os
import shutil
import subprocess

import pytest

ROOT=Path(__file__).resolve().parents[1]
PWSH=os.environ.get('PHI_TEST_PWSH') or shutil.which('pwsh')
pytestmark=pytest.mark.skipif(not PWSH,reason='PowerShell is required')
BASE=dict(MemTotal=5879692,MemFree=4000000,Cached=1000000,Shmem=800000,
          Unevictable=0,Dirty=0,Writeback=0,**{'Active(file)':100000,'Inactive(file)':100000})


@pytest.mark.parametrize('changes,omit,expected',[
    ({},[],4200000),
    ({'Shmem':1000000},[],4000000),  # tmpfs is retained RAM, not available cache
    ({'Shmem':0,'Unevictable':1000000},[],4000000),  # ramfs/locked pages
    ({'Dirty':90000,'Writeback':50000},[],4060000),
    ({'Shmem':0,'Active(file)':0,'Inactive(file)':50000},[],4050000),
    ({'Shmem':1000000,'Unevictable':500000},[],4000000),  # overlapping exclusions never go negative
    ({'MemAvailable':4500000},[],4500000),
    ({'MemAvailable':0},[],0),
    ({},['Shmem'],4000000),  # missing old-kernel metadata must not count all Cached
    ({},['Active(file)'],4000000),
    ({'MemFree':4404576,'Cached':0,'Shmem':0,'Active(file)':0,'Inactive(file)':0},[],4404576),
])
def test_memory_formulas_match(tmp_path: Path, changes: dict[str,int], omit: list[str], expected: int) -> None:
    fields=BASE|changes
    for name in omit: fields.pop(name)
    info=tmp_path/'meminfo';info.write_text(''.join(f'{key}: {value} kB\n' for key,value in fields.items()))
    script=tmp_path/'read.ps1'
    script.write_text("param([string]$Library,[string]$Info)\nSet-StrictMode -Version Latest\n$ErrorActionPreference='Stop'\n. $Library\nRead-MemorySnapshot (Get-Content -LiteralPath $Info -Raw) | ConvertTo-Json\n")
    host=subprocess.run([str(PWSH),'-NoProfile','-File',str(script),str(ROOT/'lib/Memory.ps1'),str(info)],capture_output=True,text=True,check=True,timeout=10)
    parsed=json.loads(host.stdout)
    native=subprocess.run(['awk','-f',str(ROOT/'scripts/memory-info.awk'),str(info)],capture_output=True,text=True,check=True,timeout=5)
    free,available,credit=map(int,native.stdout.split())
    assert available==parsed['available_kib']==expected
    assert free==parsed['free_kib']==fields['MemFree']
    assert credit==parsed['cache_credit_kib']


@pytest.mark.parametrize('text',[
    'MemFree: 123 kB\n',
    'MemTotal: 100 kB\nMemFree: 101 kB\n',
    'MemTotal: 100 kB\nMemFree: -1 kB\n',
    'MemTotal: 100 kB\nMemFree: 20 kB\nMemAvailable: 200 kB\n',
    'MemTotal: 100 kB\nMemFree: 20 kB\nMemFree: 30 kB\n',
    'MemTotal: 100 kB\nMemFree: 20 MB\n',
])
def test_invalid_memory_cannot_become_ready(tmp_path: Path, text: str) -> None:
    info=tmp_path/'meminfo';info.write_text(text)
    script=tmp_path/'read.ps1'
    script.write_text("param([string]$Library,[string]$Info)\n$ErrorActionPreference='Stop'\n. $Library\nRead-MemorySnapshot (Get-Content -LiteralPath $Info -Raw) | ConvertTo-Json\n")
    host=subprocess.run([str(PWSH),'-NoProfile','-File',str(script),str(ROOT/'lib/Memory.ps1'),str(info)],capture_output=True,text=True,check=False,timeout=10)
    native=subprocess.run(['awk','-f',str(ROOT/'scripts/memory-info.awk'),str(info)],capture_output=True,text=True,check=False,timeout=5)
    assert host.returncode!=0 and native.returncode!=0
