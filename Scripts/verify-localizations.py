#!/usr/bin/env python3
"""Check four-language parity and literal UI key coverage."""
from pathlib import Path
import re
root = Path(__file__).resolve().parent.parent
locales = ('en', 'zh-Hant', 'zh-Hans', 'ja')
for base, source in [('Sources/Resources/Localization', 'Sources'), ('Widget', 'Widget')]:
    sets = {}
    for locale in locales:
        path = root / base / (locale + '.lproj') / 'Localizable.strings'
        text = path.read_text()
        keys = re.findall(r'^\s*"([^"]+)"\s*=\s*"', text, flags=re.M)
        assert len(keys) == len(set(keys)), f'Duplicate keys in {path}'
        sets[locale] = set(keys)
    for locale in locales:
        assert sets[locale] == sets['en'], (base, locale, sets['en'] ^ sets[locale])
    used = set()
    for path in (root / source).rglob('*.swift'):
        used.update(re.findall(r'"((?:app|section|common|nav|battery|hardware|thermal|network|connection|live|settings|details|history|widget|preview|action)\.[A-Za-z0-9_.]+)"', path.read_text()))
    if source == 'Sources':
        for prefix, cases in [('battery', 'unknown unplugged charging full'), ('thermal', 'nominal fair serious critical unknown'), ('connection', 'wifi cellular wired other offline unknown'), ('history.metric', 'battery cpu memory network')]:
            used.update(prefix + '.' + case for case in cases.split())
    used = {key for key in used if not key.startswith('battery.100percent')}
    missing = used - sets['en']
    assert not missing, (base, sorted(missing))
    print(f'PASS: {base}: {len(sets["en"])} keys, 4 locale sets match, all literal UI keys translated')
