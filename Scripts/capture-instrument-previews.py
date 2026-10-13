#!/usr/bin/env python3
"""Explicit DEBUG battery/thermal fixtures; disk values remain measured on Simulator host."""
import subprocess,time
from pathlib import Path
sid='6D71354D-39CF-44DC-8C5E-1064BF4CE7D1';bundle='com.invivo.ios.Activity-Monitor'
out=Path(__file__).resolve().parent.parent/'Validation'
cases=[('charging-normal-en','en','en_US','charging','nominal','.68'),
       ('full-warm-en','en','en_US','full','fair','1'),
       ('unplugged-hot-en','en','en_US','unplugged','serious','.12'),
       ('charging-critical-ja','ja','ja_JP','charging','critical','.68'),
       ('unknown-zh-Hant','zh-Hant','zh_HK','unknown','unknown','.68'),
       ('charging-normal-zh-Hans','zh-Hans','zh_CN','charging','nominal','.68')]
for name,lang,locale,battery,thermal,level in cases:
 subprocess.run(['xcrun','simctl','terminate',sid,bundle],capture_output=True)
 subprocess.run(['xcrun','simctl','launch',sid,bundle,'--design-preview','--battery-state',battery,'--thermal-state',thermal,'--battery-level',level,'-AppleLanguages',f'({lang})','-AppleLocale',locale],check=True,capture_output=True)
 time.sleep(5)
 subprocess.run(['xcrun','simctl','io',sid,'screenshot',str(out/f'instruments-{name}.png')],check=True,capture_output=True)
 print(name,flush=True)
