import json
from pathlib import Path
import re

WORKSPACE = Path("k:/DCS_ATC")
UPDATES = WORKSPACE / 'tools' / 'crp_updates.json'

if not UPDATES.exists():
    print('crp_updates.json not found at', UPDATES)
    raise SystemExit(1)

updates = json.loads(UPDATES.read_text(encoding='utf-8'))
changed = []
for u in updates:
    tf = u.get('target_file')
    lua_block = u.get('lua_block')
    if not tf:
        print('No target file for', u.get('airfield'))
        continue
    p = Path(tf)
    if not p.exists():
        print('Target file missing:', tf)
        continue
    data = p.read_text(encoding='utf-8')
    m = re.search(r'crps\s*=\s*\{', data)
    if not m:
        print('No crps block in', p)
        continue
    start = m.start()
    # find matching closing brace for this crps table
    i = data.find('{', m.end()-1)
    if i == -1:
        print('Malformed crps in', p)
        continue
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
        print('Could not find end of crps block in', p)
        continue
    # consume trailing comma and whitespace/newlines
    j = end
    while j < len(data) and data[j] in ' \t\r\n,':
        j += 1
    newdata = data[:start] + '\n' + lua_block + data[j:]
    if newdata != data:
        p.write_text(newdata, encoding='utf-8')
        changed.append(str(p))
        print('Fixed', p)
    else:
        print('No change for', p)

print('\nDone. Fixed %d files.' % len(changed))
