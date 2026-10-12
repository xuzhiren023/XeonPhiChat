"""Negative native-execution gate and package checks; no model or Phi required."""
from pathlib import Path
import json
import os
import subprocess
import xml.etree.ElementTree as ET

import pytest

ROOT = Path(__file__).resolve().parents[1]


def test_non_knc_cannot_start_inference() -> None:
    if os.uname().machine == 'k1om':
        pytest.skip('Host-only negative test')
    result = subprocess.run(
        ['bash', str(ROOT / 'scripts/chat-worker.sh'),
         '/root/knc-phase3-run-test', '/root/knc-chat-abcdef'],
        capture_output=True, text=True, timeout=5, check=False)
    assert result.returncode != 0
    assert 'Native K1OM required' in result.stderr


def test_all_model_pins_and_budget_accounting() -> None:
    for file in (ROOT / 'config/models').glob('*.yaml'):
        model = json.loads(file.read_text())
        assert len(model['revision']) == 40
        assert len(model['sha256']) == 64
        assert model['context_tokens'] == 2048
        file_mib = (model['file_size_bytes'] + 1048575) // 1048576
        assert file_mib + model['estimated_peak_runtime_mib'] <= model['minimum_memory_mib']


def test_wpf_layout_xml_is_valid_and_has_required_controls() -> None:
    xaml = (ROOT / 'ChatWindow.xaml').read_text()
    tree = ET.fromstring(xaml)
    names = {node.attrib.get('{http://schemas.microsoft.com/winfx/2006/xaml}Name') for node in tree.iter()}
    assert {'Model', 'Recent', 'New', 'Send', 'Stop', 'ThermalStatus', 'MemoryStatus', 'Restore', 'Connect', 'Load', 'LoadProgress', 'LoadStatus'} <= names
    assert not ({'Context', 'Batch', 'Length', 'Mode', 'Benchmark', 'Validate', 'Approve', 'Cooling'} & names)
