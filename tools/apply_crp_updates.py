import re
import json
from pathlib import Path

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
    # Replace the first occurrence of a crps = { ... }, block
    # Allow and remove any repeated orphaned `{ ... },` entries that may follow the block
    pattern = re.compile(r"\n\s*crps\s*=\s*\{[\s\S]*?\},\s*\n(?:\s*\{[\s\S]*?\},\s*\n)*", re.M)
    if pattern.search(data):
        newdata = pattern.sub('\n' + lua_block + '\n', data, count=1)
        if newdata != data:
            p.write_text(newdata, encoding='utf-8')
            changed.append(str(p))
            print('Updated', p)
        else:
            print('No change for', p)
    else:
        # Try replacing a more specific block 'crps = {' without leading newline
        pattern2 = re.compile(r"crps\s*=\s*\{[\s\S]*?\},\s*\n", re.M)
        if pattern2.search(data):
            newdata = pattern2.sub(lua_block + '\n', data, count=1)
            p.write_text(newdata, encoding='utf-8')
            changed.append(str(p))
            print('Updated (alt) ', p)
        else:
            print('Failed to find crps block in', p)

print('\nDone. Updated %d files.' % len(changed))
