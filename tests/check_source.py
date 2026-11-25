"""Static integration checks, not a Luau compiler. Run from archive root with Python 3."""
from pathlib import Path
import re
from collections import Counter

root=Path('src')
mods=root/'server'/'AI'
files=sorted(root.rglob('*.luau'))

assert len(files)==32, f'Expected 32 Luau scripts, got {len(files)}'

texts={p:p.read_text(encoding='utf-8') for p in files}
source='\n'.join(texts.values())
modules={p.stem for p in mods.glob('*.luau')}
refs=set(re.findall(r'require\((?:AI|script\.Parent)\.(\w+)\)',source))

assert refs <= modules, refs-modules

for name,alias in [('Settings','SETTINGS'),('Configuration','Config')]:
    keys=re.findall(r'\b(\w+)\s*=',texts[mods/(name+'.luau')])
    assert all(v==1 for v in Counter(keys).values()), f'Duplicate {name} key'
    uses=set(re.findall(r'\b(?:ctx\.)?'+alias+r'\.(\w+)',source))
    assert uses <= set(keys), (name,uses-set(keys))

ctx_refs=set(re.findall(r'ctx\.(\w+)',source))
assigned=set(re.findall(r'ctx\.(\w+)\s*=(?!=)',source)) | set(re.findall(r'\b(\w+)\s*=(?!=)',texts[root/'server'/'AIController.luau']))

assert ctx_refs<=assigned,ctx_refs-assigned

for path,txt in texts.items():
    if re.search(r'ctx\.humanoid:(?:MoveTo|Move)\(|ctx\.humanoid\.Jump\s*=',txt):
        assert path==mods/'Movement.luau',str(path)

assert all((root/p).is_file() for p in ['server/init.server.luau','server/AIController.luau','client/CameraEffects.client.luau','client/VisualHandler.client.luau','shared/Signal.luau'])

print(f'PASS {len(files)} source files, {len(modules)} AI modules, {len(refs)} referenced module names, configuration keys, context references and movement ownership.')
print('Static name checks are not type checking or runtime verification.')
