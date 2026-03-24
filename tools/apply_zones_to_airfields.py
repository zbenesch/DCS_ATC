import re
from pathlib import Path

WORKSPACE = Path('k:/DCS_ATC')
ZONES_FILE = WORKSPACE / 'tools' / 'zones_input.lua'
AIRFIELDS_DIR = WORKSPACE / 'Mods' / 'Services' / 'DCS-ATC' / 'Scripts' / 'airfields' / 'Caucasus'

if not ZONES_FILE.exists():
    print('zones_input.lua not found; please paste zones into', ZONES_FILE)
    raise SystemExit(1)

zones_text = ZONES_FILE.read_text(encoding='utf-8')
# find all zone blocks with name, x, y, radius
pattern = re.compile(r"\{[\s\S]*?\[\"name\"\]\s*=\s*\"([^\"]+)\"[\s\S]*?\[\"x\"\]\s*=\s*([-\d\.]+)[\s\S]*?\[\"y\"\]\s*=\s*([-\d\.]+)[\s\S]*?\[\"radius\"\]\s*=\s*([-\d\.]+)[\s\S]*?\}", re.M)
entries = pattern.findall(zones_text)
if not entries:
    print('No zone entries parsed; pattern may need adjustment')
    raise SystemExit(1)

# group by airfield base name (name like 'Kutaisi CRP1')
from collections import defaultdict
airfields = defaultdict(list)
for name, x, y, radius in entries:
    parts = name.rsplit(' ', 1)
    if len(parts) == 2 and parts[1].upper().startswith('CRP'):
        base = parts[0]
        try:
            seq = int(parts[1][3:])
        except Exception:
            seq = None
    else:
        # fallback: try split by last space
        base = parts[0]
        seq = None
    airfields[base].append({'name': name, 'x': float(x), 'y': float(y), 'radius': float(radius), 'seq': seq})

# build map of runway display name -> file path
runway_map = {}
for f in AIRFIELDS_DIR.glob('*.lua'):
    txt = f.read_text(encoding='utf-8')
    m = re.search(r'ATC\.runways\[\"([^\"]+)\"\]', txt)
    if m:
        runway_map[m.group(1)] = f

# helper to replace crps block with brace-balanced parsing
def replace_crps_in_file(path, lua_block):
    data = path.read_text(encoding='utf-8')
    m = re.search(r'crps\s*=\s*\{', data)
    if not m:
        print('No crps block in', path)
        return False
    start = m.start()
    i = data.find('{', m.end()-1)
    if i == -1:
        print('Malformed crps in', path)
        return False
    depth = 0
    end = -1
    while i < len(data):
        c = data[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    if end == -1:
        print('Could not find end of crps in', path)
        return False
    # remove trailing comma/newlines
    j = end
    while j < len(data) and data[j] in ' \t\r\n,':
        j += 1
    newdata = data[:start] + '\n' + lua_block + data[j:]
    path.write_text(newdata, encoding='utf-8')
    return True

updated = []
for base, items in airfields.items():
    # only update if we have up to 6 entries (prefer those with seq)
    if len(items) < 1:
        continue
    # sort by seq if present
    if all(it['seq'] for it in items):
        items.sort(key=lambda x: x['seq'])
    else:
        items = items[:6]
    # build lua crps block
    lines = ['    crps = {']
    seq = 1
    for it in items[:6]:
        # some names may include full airfield name + CRPn, keep name
        name = it['name']
        x = it['x']
        y = it['y']
        r = it['radius']
        lines.append(f'        {{ name="{name}", seq={seq}, x={x}, y={y}, radius={r} }},')
        seq += 1
    lines.append('    },\n')
    lua_block = '\n'.join(lines)
    # find matching file
    target = None
    if base in runway_map:
        target = runway_map[base]
    else:
        # try normalize: lower, remove non-alnum
        bnorm = re.sub(r'[^a-z0-9]', '', base.lower())
        for rn, p in runway_map.items():
            if re.sub(r'[^a-z0-9]', '', rn.lower()) == bnorm:
                target = p
                break
    if not target:
        print('No airfield file found for', base)
        continue
    ok = replace_crps_in_file(target, lua_block)
    if ok:
        updated.append(str(target))
        print('Updated', target)

print('\nDone. Updated %d files.' % len(updated))
