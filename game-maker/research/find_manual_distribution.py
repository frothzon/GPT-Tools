from pathlib import Path
import re
for path in [Path('C:/Program Files/GameMaker/GameMaker.dll'), Path('C:/Agent Tools/game-maker/node_modules/@gamemaker/gm-cli/dist/read-impl-2OH3BWGI.js')]:
    data = path.read_bytes()
    for encoding in ('utf-8', 'utf-16-le'):
        text = data.decode(encoding, errors='ignore')
        matches = sorted(set(re.findall(r'https?://[^\s"<>\x00\x01\x02]+', text)))
        for value in matches:
            if any(word in value.casefold() for word in ('manual', 'robohelp')):
                print(path.name, value[:300])
