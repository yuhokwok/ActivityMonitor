#!/usr/bin/env python3
"""Capture explicitly labelled DEBUG battery fixtures; other telemetry remains live."""
import subprocess, time, signal
from pathlib import Path
sid = '6D71354D-39CF-44DC-8C5E-1064BF4CE7D1'
bundle = 'com.invivo.ios.Activity-Monitor'
out = Path(__file__).resolve().parent.parent / 'Validation'
def run(*args):
    return subprocess.run(['xcrun','simctl',*args], check=True, capture_output=True)
def launch(language, locale, level):
    subprocess.run(['xcrun','simctl','terminate',sid,bundle], capture_output=True)
    run('launch',sid,bundle,'--design-preview','--battery-level',level,'-AppleLanguages',f'({language})','-AppleLocale',locale)
for language, locale, level in [('en','en_US','.95'),('zh-Hant','zh_HK','.68'),('zh-Hans','zh_CN','.12'),('ja','ja_JP','.95')]:
    launch(language, locale, level)
    time.sleep(6)
    run('io',sid,'screenshot',str(out/f'dashboard-{language}-preview.png'))
launch('zh-Hant','zh_HK','.68')
time.sleep(6)
(out/'battery-animation-preview.mp4').unlink(missing_ok=True)
p = subprocess.Popen(['xcrun','simctl','io',sid,'recordVideo','--codec=h264',str(out/'battery-animation-preview.mp4')], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
time.sleep(1)
launch('zh-Hant','zh_HK','.95')
time.sleep(20)
p.send_signal(signal.SIGINT)
_, errors = p.communicate(timeout=10)
if p.returncode not in (0, 130):
    raise RuntimeError(errors.decode())
print('Captured four locales and 20-second DEBUG animation preview.')
