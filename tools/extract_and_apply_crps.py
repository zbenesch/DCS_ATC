#!/usr/bin/env python3
# Auto-extract CRP zones from mission and update airfield Lua files
import re
import json
from pathlib import Path

MISSION_PATH = Path('k:/DCS_ATC/testmiz/atc/mission')
AIRFIELDS_DIR = Path('k:/DCS_ATC/Mods/Services/DCS-ATC/Scripts/airfields/Caucasus')

with open(MISSION_PATH, encoding='utf-8') as f:
    mission = f.read()

# Extract all CRP zones
zone_pattern = re.compile(r'\["name"\]\s*=\s*"([^"]+CRP\d+)"[\s\S]*?\["x"\]\s*=\s*([\-\d\.]+)[\s\S]*?\["y"\]\s*=\s*([\-\d\.]+)[\s\S]*?\["radius"\]\s*=\s*([\-\d\.]+)', re.M)
zones = zone_pattern.findall(mission)

# Group by airfield
crps_by_airfield = {}
for name, x, y, radius in zones:
    base, crp = name.rsplit(' ', 1)
    crps_by_airfield.setdefault(base, []).append({
        'name': name,
        'x': float(x),
        'y': float(y),
        'radius': float(radius),
        'seq': int(crp[3:]) if crp.startswith('CRP') and crp[3:].isdigit() else None
    })

# Sort by sequence
for airfield, crps in crps_by_airfield.items():
    crps.sort(key=lambda z: z['seq'] if z['seq'] is not None else 99)

# Update Lua files
for lua_file in AIRFIELDS_DIR.glob('*.lua'):
    with open(lua_file, encoding='utf-8') as f:
        lua = f.read()
    m = re.search(r'ATC\.runways\["([^"]+)"\]', lua)
    if not m:
        continue
    airfield = m.group(1)
    if airfield not in crps_by_airfield:
        continue
    # Build new crps block
    crps = crps_by_airfield[airfield]
    lines = ['    crps = {']
    for i, z in enumerate(crps, 1):
        lines.append(f'        {{ name="{z["name"]}", seq={i}, x={z["x"]}, y={z["y"]}, radius={z["radius"]} }},')
    lines.append('    },\n')
    crps_block = '\n'.join(lines)
    # Replace old crps block
    lua_new = re.sub(r'crps\s*=\s*\{[\s\S]*?\},\s*\n', crps_block + '\n', lua, count=1)
    with open(lua_file, 'w', encoding='utf-8') as f:
        f.write(lua_new)
    print(f'Updated {lua_file}')
print('Done.')
