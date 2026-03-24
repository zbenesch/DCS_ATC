import re
import json
from pathlib import Path

WORKSPACE = Path("k:/DCS_ATC")
MISSION = WORKSPACE / "testmiz" / "atc" / "mission"
AIRFIELDS_DIR = WORKSPACE / "Mods" / "Services" / "DCS-ATC" / "Scripts" / "airfields"

text = MISSION.read_text(encoding='utf-8')
# Find triggers.zones block
m = re.search(r"\[\"triggers\"\]\s*=\s*\{[\s\S]*?\[\"zones\"\]\s*=\s*\{([\s\S]*?)\},\s*-- end of \[\"zones\"\]", text)
if not m:
    print('no zones block found')
    exit(1)
zones_text = m.group(1)

# Split zones by the pattern: -- end of [n]
zone_blocks = re.split(r"},\s*-- end of \[\d+\]", zones_text)

zones = []
for zb in zone_blocks:
    # extract name, x, y, radius
    name_m = re.search(r'\["name"\]\s*=\s*"([^"]+)"', zb)
    x_m = re.search(r'\["x"\]\s*=\s*([-0-9\.]+)', zb)
    y_m = re.search(r'\["y"\]\s*=\s*([-0-9\.]+)', zb)
    r_m = re.search(r'\["radius"\]\s*=\s*([-0-9\.]+)', zb)
    if name_m and x_m and y_m and r_m:
        name = name_m.group(1)
        x = float(x_m.group(1))
        y = float(y_m.group(1))
        radius = float(r_m.group(1))
        zones.append({'name': name, 'x': x, 'y': y, 'radius': radius})

# Group by airfield prefix before ' CRP'
groups = {}
for z in zones:
    if ' CRP' in z['name']:
        ab = z['name'].split(' CRP')[0]
        seq_part = z['name'].split('CRP')[-1]
        try:
            seq = int(seq_part)
        except:
            seq = None
        groups.setdefault(ab, []).append({'seq': seq, 'name': z['name'], 'x': z['x'], 'y': z['y'], 'radius': z['radius']})

# For each group, sort by seq and build lua crps text
updates = []
for ab, crps in groups.items():
    crps_sorted = sorted([c for c in crps if c['seq'] is not None], key=lambda c: c['seq'])
    if not crps_sorted:
        continue
    lua_entries = []
    for c in crps_sorted:
        lua_entries.append('        { name="%s", seq=%d, x=%.12f, y=%.12f, radius=%.4f },' % (c['name'], c['seq'], c['x'], c['y'], c['radius']))
    lua_block = '    crps = {\n' + '\n'.join(lua_entries) + '\n    },\n'

    # Find airfield file that contains ATC.runways["<ab>"]
    target_file = None
    for p in AIRFIELDS_DIR.rglob('*.lua'):
        data = p.read_text(encoding='utf-8')
        if re.search(r'ATC\.runways\s*\[\"%s\"\]' % re.escape(ab), data):
            target_file = p
            break
    if not target_file:
        # try matching filename by normalized name
        norm = ab.lower().replace(' ', '-').replace("'", "").replace('—','-')
        for p in AIRFIELDS_DIR.rglob('*.lua'):
            if norm in p.name.lower():
                target_file = p
                break
    updates.append({'airfield': ab, 'target_file': str(target_file) if target_file else None, 'lua_block': lua_block})

out = WORKSPACE / 'tools' / 'crp_updates.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(updates, indent=2), encoding='utf-8')
print('wrote', out)
print('found %d airfields' % len(updates))
