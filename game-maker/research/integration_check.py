"""Real compiler/scenario integration; all working projects stay unchanged."""
from pathlib import Path
import json
from gmtool.index import build_index
from gmtool.change_plans import prepare
from gmtool.verification import verify
from gmtool.scenarios import run
from gmtool.transactions import sha256_bytes
from gmtool.gm_cli import source_snapshot
from gmtool.workspace import save

tool = Path('C:/Agent Tools/game-maker')
project = Path('C:/Users/johns/GameMakerProjects/Simple3D/Simple3D.yyp')
index = build_index(project)
before = source_snapshot(index.root)
source = index.resources_by_name['aabb'].sources[0]
manifest = {'operations': [{'kind':'replace','spec':'AABB.code','expectedHash':sha256_bytes(source.path.read_bytes()),'from':str(source.path)}]}
plan = prepare(tool, project, manifest, {'toolchain':'GMS2@2024.14.4','timeout':180,'docsChannel':'project'})
print('PLAN', plan['planId'], flush=True)
evidence = verify(tool, plan['planId'])
print('CHECKS', {k:v['status'] for k,v in evidence['checks'].items()}, flush=True)
suite = {'name':'runtime-smoke','tests':[{'name':'actual-gml-arithmetic','assert':'clamp(30,0,25)==25'}, {'name':'array-runtime','assert':'array_length([1,2,3])==3'}]}
result = run(tool, plan['planId'], suite)
print('SCENARIO',result['status'],result.get('problems'),flush=True)
save(tool/'research/integration-result.json', {'planId':plan['planId'],'verification':evidence,'scenario':result,'projectUnchanged':source_snapshot(index.root)==before})
