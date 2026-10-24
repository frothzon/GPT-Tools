from pathlib import Path
from gmtool.index import build_index
from gmtool.change_plans import prepare
from gmtool.verification import verify
from gmtool.scenarios import run
from gmtool.transactions import sha256_bytes
from gmtool.gm_cli import source_snapshot
from gmtool.workspace import load, save

tool = Path('C:/Agent Tools/game-maker')
project = Path('C:/Users/johns/OneDrive/Documents/GitHub/Crafting_Game_V3/crafting_game_v3/crafting_game_v3.yyp')
index = build_index(project); before = source_snapshot(index.root)
source = index.resources_by_name['add_item'].sources[0]
plan = prepare(tool, project, {'operations':[{'kind':'replace','spec':'add_item.code','expectedHash':sha256_bytes(source.path.read_bytes()),'from':str(source.path)}]}, {'toolchain':'GMS2@2024.14.4','timeout':180,'docsChannel':'project'})
print('PLAN',plan['planId'],flush=True)
evidence = verify(tool,plan['planId'])
print('CHECKS',{k:v['status'] for k,v in evidence['checks'].items()},flush=True)
result = run(tool,plan['planId'],load(tool/'tests/fixtures/scenarios/crafting_game_v3.json'))
print('ASSERTIONS',result['status'],result.get('problems'),flush=True)
save(tool/'research/project-integration-result.json',{'planId':plan['planId'],'verification':evidence,'scenario':result,'projectUnchanged':source_snapshot(index.root)==before})
