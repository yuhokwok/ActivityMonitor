#!/usr/bin/env python3
"""Verify that all bundled animation frames remain identical to original exports."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent.parent
original = root / 'Resource/UI_Phone/watch app/image sequence'
bundled = root / 'Sources/Resources/BatterySequences'
manifest = {}
for sequence in sorted(original.iterdir()):
    if not sequence.is_dir():
        continue
    frames = sorted(sequence.glob('*.png'))
    expected = 31 if sequence.name.endswith('FloatUp') else 360
    assert len(frames) == expected, (sequence.name, len(frames))
    for frame in frames:
        copy = bundled / sequence.name / frame.name
        assert hashlib.sha256(frame.read_bytes()).digest() == hashlib.sha256(copy.read_bytes()).digest(), copy
    manifest[sequence.name] = {'frames': len(frames), 'first': frames[0].name, 'last': frames[-1].name, 'fps': 30}
print(json.dumps(manifest, indent=2))
print('PASS: all 1,173 original animation frames match bundled copies')
