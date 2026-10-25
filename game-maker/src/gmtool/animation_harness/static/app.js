const TOKEN=window.HARNESS_TOKEN;
const $=selector=>document.querySelector(selector);
const stage=$('#stage'),ctx=stage.getContext('2d');
let state=null,selectedCollection=null,selectedEntity=null,selectedClip=null,selectedMap=null,selectedTrack=0,timeMs=0,speed=1,playing=false,sliceMode=false,cutStart=null,cutEnd=null,sliceSource=null,lastTick=performance.now(),lastDraw=0,renderSerial=0;

async function api(action,args={}){
  const response=await fetch('/api',{method:'POST',headers:{'Content-Type':'application/json','X-Gmtool-Token':TOKEN},body:JSON.stringify({action,args})});
  const value=await response.json();if(!response.ok)throw Error(value.error||response.statusText);return value;
}
function notify(message,error=false){const node=$('#toast');node.textContent=message;node.className='show'+(error?' error':'');clearTimeout(notify.timer);notify.timer=setTimeout(()=>node.className='',3600)}
function currentCollection(){return state?.project.collections.find(c=>c.id===selectedCollection)||state?.project.collections[0]}
function currentEntity(){const c=currentCollection();return c?.entities.find(e=>e.id===selectedEntity)||c?.entities[0]}
function currentClip(){const e=currentEntity();return e?.animations.find(a=>a.name===selectedClip)||e?.animations[0]}
function assetURL(file){return file?`data:image/png;base64,${state.assets[file.asset_id]||''}`:''}
function setCanvasSize(){stage.width=state.project.settings.canvas[0];stage.height=state.project.settings.canvas[1]}
function selectCharacter(collection,entity){selectedCollection=collection.id;selectedEntity=entity.id;selectedClip=entity.animations[0]?.name;selectedTrack=0;timeMs=0;renderAll()}
function refreshProject(value){state=value;selectedCollection=value.project.collections[0]?.id||null;selectedEntity=value.project.collections[0]?.entities[0]?.id||null;selectedClip=value.project.collections[0]?.entities[0]?.animations[0]?.name||null;selectedTrack=0;timeMs=0;sliceMode=false;sliceSource=null;setCanvasSize();renderAll()}
function fmt(value){return Number.isFinite(Number(value))?Number(Number(value).toFixed(3)):0}

function renderAll(){
  if(!state)return;const entity=currentEntity(),animation=currentClip();setCanvasSize();
  $('#projectName').textContent=state.project.name;$('#currentCharacter').textContent=entity?.name||'No character';$('#timelineTitle').textContent=entity?`${entity.name} · ${animation?.name||''}`:'Choose a character';
  $('#clipSelect').replaceChildren(...(entity?.animations||[]).map(clip=>{const option=document.createElement('option');option.value=clip.name;option.textContent=clip.name;option.selected=clip.name===selectedClip;return option}));
  $('#timeSlider').max=animation?.duration||1000;$('#timeSlider').value=timeMs;$('#timeReadout').textContent=Math.round(timeMs);$('#stageHint').textContent=entity?`${stage.width} × ${stage.height} · ${entity.bones.length} bones · ${entity.parts.length} parts`:'Import art or select a character';
  drawCharacters();drawTimeline();fillInspector();renderPose();
}
function drawCharacters(){
  const list=$('#characterList');list.replaceChildren();
  for(const collection of state.project.collections)for(const entity of collection.entities){
    const row=document.createElement('div');row.className='character-item'+(entity.id===selectedEntity?' selected':'');
    const image=document.createElement('img');image.className='thumb';image.src=assetURL(entity.files[0]);
    const label=document.createElement('span');label.className='char-name';label.textContent=entity.name;
    const meta=document.createElement('small');meta.className='char-meta';meta.textContent=`${entity.parts.length} parts · ${entity.animations.length} clips`;label.append(meta);row.append(image,label);
    row.onclick=()=>selectCharacter(collection,entity);list.append(row);
  }
}
function drawTimeline(){
  const entity=currentEntity(),animation=currentClip(),rows=$('#tracks');rows.replaceChildren();$('#trackSelect').replaceChildren();if(!entity||!animation)return;
  animation.timelines.forEach((track,index)=>{
    const option=document.createElement('option');option.value=index;option.textContent=`${track.object_type==='bone'?'◉':'▧'} ${track.name}`;$('#trackSelect').append(option);
    const row=document.createElement('div');row.className='track-row';const label=document.createElement('span');label.className='track-name';label.textContent=track.name;row.append(label);
    for(let i=0;i<track.keys.length/18;i++){const marker=document.createElement('button');marker.className='key-marker';marker.title=`${track.keys[i*18]} ms`;marker.onclick=()=>{selectedTrack=index;setTime(track.keys[i*18])};row.append(marker)}rows.append(row);
  });
  $('#trackSelect').value=selectedTrack;const events=$('#events');events.replaceChildren();
  for(const event of animation.events||[]){const pill=document.createElement('span');pill.className='event-pill';pill.textContent=`${event.time} · ${event.name}`;events.append(pill)}
}
function fillInspector(){
  const entity=currentEntity(),animation=currentClip();if(!entity||!animation){$('#keySelect').replaceChildren();return}
  selectedTrack=Math.max(0,Math.min(selectedTrack,animation.timelines.length-1));const track=animation.timelines[selectedTrack];if(!track){$('#keySelect').replaceChildren();return}
  const options=[];for(let i=0;i<track.keys.length/18;i++){const option=document.createElement('option');option.value=i;option.textContent=`Key ${i+1} · ${track.keys[i*18]} ms`;options.push(option)}
  $('#keySelect').replaceChildren(...options);let keyIndex=options.findIndex(option=>Number(option.textContent.split('·')[1])===Math.round(timeMs));if(keyIndex<0)keyIndex=0;$('#keySelect').value=keyIndex;
  const key=track.keys.slice(keyIndex*18,keyIndex*18+18),isSprite=track.object_type==='sprite';$('#keyTime').value=key[0]??0;$('#valueX').value=fmt(key[1]);$('#valueY').value=fmt(key[2]);$('#valueAngle').value=fmt(key[3]);$('#valueScaleX').value=fmt(key[4]);$('#valueScaleY').value=fmt(key[5]);$('#valueAlpha').value=fmt(key[6]);$('#valueCurve').value=String(key[11]??1);
  const file=entity.files[Number(key[9])];$('#valuePivotX').value=fmt(key[7]<=-9999?(file?.pivot_x??.5):key[7]);$('#valuePivotY').value=fmt(key[8]<=-9999?(file?.pivot_y??.5):key[8]);
  for(let i=1;i<=4;i++)$('#valueC'+i).value=fmt(key[11+i]??.5);
  $('#valueFile').replaceChildren(...entity.files.map((entry,index)=>{const option=document.createElement('option');option.value=index;option.textContent=`${index}: ${entry.name}`;option.selected=index===Number(key[9]);return option}));
  for(const id of ['valuePivotX','valuePivotY','valueFile'])$('#'+id).disabled=!isSprite;
  $('#zOrder').value=track.object_type==='sprite'?Math.max(0,...animation.mainline.flatMap(main=>main.objects||[]).filter(object=>object[1]===selectedTrack).map(object=>object[4])):0;
  $('#partSelect').replaceChildren(...entity.parts.map(part=>{const option=document.createElement('option');option.value=part;option.textContent=part;return option}));$('#selectionTitle').textContent=track.name;
  const maps=entity.character_maps||[];if(!maps.some(map=>map.name===selectedMap))selectedMap=maps[0]?.name||null;
  $('#mapSelect').replaceChildren(...maps.map(map=>{const option=document.createElement('option');option.value=map.name;option.textContent=map.name;option.selected=map.name===selectedMap;return option}));
  const fileOptions=entity.files.map((entry,index)=>{const option=document.createElement('option');option.value=index;option.textContent=`${index}: ${entry.name}`;return option});
  $('#mapSource').replaceChildren(...fileOptions.map(option=>option.cloneNode(true)));
  const hide=document.createElement('option');hide.value='-1';hide.textContent='Hide attachment';$('#mapTarget').replaceChildren(hide,...fileOptions);
  const active=state.project.settings.preview_maps?.[entity.id]||[];$('#previewMap').textContent=active.includes(selectedMap)?'Preview On':'Preview';
  $('#checkList').replaceChildren();for(const text of [`${entity.bones.length} bones and ${entity.parts.length} parts`,`${animation.timelines.length} tracks and ${animation.events?.length||0} events`,'Project artwork embedded']){const line=document.createElement('div');line.className='check';line.textContent=text;$('#checkList').append(line)}
}
async function renderPose(){
  if(!state||sliceMode)return;const entity=currentEntity(),animation=currentClip();if(!entity||!animation)return;const serial=++renderSerial;
  try{const result=await api('render',{collection_id:currentCollection().id,entity_id:entity.id,animation:animation.name,time_ms:timeMs});if(serial!==renderSerial||sliceMode)return;const image=new Image();image.onload=()=>{if(serial!==renderSerial)return;ctx.clearRect(0,0,stage.width,stage.height);ctx.drawImage(image,0,0)};image.src='data:image/png;base64,'+result.png}
  catch(error){notify(error.message,true)}
}
function setTime(value){const animation=currentClip();if(!animation)return;timeMs=Math.max(0,Math.min(animation.duration,Number(value)||0));$('#timeSlider').value=timeMs;$('#timeReadout').textContent=Math.round(timeMs);fillInspector();renderPose()}

$('#clipSelect').onchange=event=>{selectedClip=event.target.value;selectedTrack=0;setTime(0);renderAll()};
$('#trackSelect').onchange=event=>{selectedTrack=Number(event.target.value);drawTimeline();fillInspector()};
$('#keySelect').onchange=event=>{const track=currentClip()?.timelines[selectedTrack],index=Number(event.target.value);if(track)setTime(track.keys[index*18])};
$('#timeSlider').oninput=event=>setTime(event.target.value);$('#speedSelect').onchange=event=>speed=Number(event.target.value);
$('#playButton').onclick=()=>{playing=!playing;$('#playButton').textContent=playing?'❚❚':'▶';lastTick=performance.now()};
$('#stopButton').onclick=()=>{playing=false;$('#playButton').textContent='▶';setTime(0)};
function tick(now){const dt=now-lastTick;lastTick=now;if(playing){const animation=currentClip();if(animation){let next=timeMs+dt*speed;if(animation.looping){next=((next%animation.duration)+animation.duration)%animation.duration}else if((speed>=0&&next>=animation.duration)||(speed<0&&next<=0)){next=speed>=0?animation.duration:0;playing=false;$('#playButton').textContent='▶'}timeMs=Math.max(0,Math.min(animation.duration,next));$('#timeSlider').value=timeMs;$('#timeReadout').textContent=Math.round(timeMs);if(now-lastDraw>85){fillInspector();renderPose();lastDraw=now}}}requestAnimationFrame(tick)}requestAnimationFrame(tick);

$('#applyValues').onclick=async()=>{
  const entity=currentEntity(),animation=currentClip(),keyIndex=Number($('#keySelect').value);if(!entity||!animation)return;
  try{const values={time_ms:Number($('#keyTime').value)};for(const [field,id] of [['x','valueX'],['y','valueY'],['angle','valueAngle'],['scale_x','valueScaleX'],['scale_y','valueScaleY'],['alpha','valueAlpha'],['pivot_x','valuePivotX'],['pivot_y','valuePivotY']])if(!$('#'+id).disabled)values[field]=Number($('#'+id).value);values.curve=Number($('#valueCurve').value);for(let i=1;i<=4;i++)values['c'+i]=Number($('#valueC'+i).value);if(!$('#valueFile').disabled)values.file_index=Number($('#valueFile').value);
    const result=await api('set_keys',{collection_id:currentCollection().id,entity_id:entity.id,animation:animation.name,timeline_index:selectedTrack,key_index:keyIndex,values,z:Number($('#zOrder').value)});state.project=result.project;notify(`Updated ${animation.timelines[selectedTrack].name} at ${$('#keyTime').value} ms`);renderAll()
  }catch(error){notify(error.message,true)}
};
$('#insertKey').onclick=async()=>{const entity=currentEntity(),animation=currentClip();if(!entity||!animation)return;try{const result=await api('add_key',{collection_id:currentCollection().id,entity_id:entity.id,animation:animation.name,timeline_index:selectedTrack,time_ms:Math.round(timeMs)});state.project=result.project;notify(`Keyframe ready at ${Math.round(timeMs)} ms`);renderAll()}catch(error){notify(error.message,true)}};
$('#addEvent').onclick=async()=>{const entity=currentEntity(),animation=currentClip();if(!entity||!animation)return;try{const payload=$('#eventPayload').value.trim()?JSON.parse($('#eventPayload').value):{};const result=await api('add_event',{collection_id:currentCollection().id,entity_id:entity.id,animation:animation.name,name:$('#eventName').value,time_ms:Math.round(timeMs),payload});state.project=result.project;notify(`Added ${result.event.name} at ${result.event.time} ms`);renderAll()}catch(error){notify(error.message,true)}};

function drawSlicePreview(){if(!sliceSource?.image)return;ctx.clearRect(0,0,stage.width,stage.height);ctx.drawImage(sliceSource.image,0,0);if(cutStart&&cutEnd){ctx.save();ctx.strokeStyle='#ffca72';ctx.lineWidth=Math.max(1,stage.width/300);ctx.setLineDash([5,3]);ctx.beginPath();ctx.moveTo(...cutStart);ctx.lineTo(...cutEnd);ctx.stroke();ctx.fillStyle='#fff1d1';ctx.beginPath();ctx.arc((cutStart[0]+cutEnd[0])/2,(cutStart[1]+cutEnd[1])/2,3,0,Math.PI*2);ctx.fill();ctx.restore()}}
async function showSliceArt(){const entity=currentEntity(),animation=currentClip(),part=$('#partSelect').value;if(!entity||!animation||!part)return;const key=`${entity.id}:${animation.name}:${part}`;if(sliceSource?.key===key){drawSlicePreview();return}const result=await api('part_art',{collection_id:currentCollection().id,entity_id:entity.id,animation:animation.name,part});stage.width=result.width;stage.height=result.height;selectedTrack=result.timeline_index;const image=new Image();sliceSource={key,image,width:result.width,height:result.height};image.onload=()=>{drawSlicePreview();$('#stageHint').textContent=`Cutting ${part} · ${stage.width} × ${stage.height}`};image.src='data:image/png;base64,'+result.image}
$('#sliceMode').onclick=async()=>{sliceMode=!sliceMode;cutStart=null;cutEnd=null;$('#sliceMode').classList.toggle('primary',sliceMode);stage.style.cursor=sliceMode?'crosshair':'default';if(sliceMode){try{await showSliceArt()}catch(error){sliceMode=false;notify(error.message,true)}}else{sliceSource=null;renderAll()}notify(sliceMode?'Drag a cut line across the selected source image.':'Slice mode off')};
$('#partSelect').onchange=()=>{sliceSource=null;if(sliceMode)showSliceArt().catch(error=>notify(error.message,true))};
function canvasPoint(event){const rect=stage.getBoundingClientRect();return[(event.clientX-rect.left)*stage.width/rect.width,(event.clientY-rect.top)*stage.height/rect.height]}
stage.onpointerdown=event=>{if(!sliceMode)return;stage.setPointerCapture(event.pointerId);cutStart=canvasPoint(event);cutEnd=cutStart;drawSlicePreview()};
stage.onpointermove=event=>{if(!sliceMode||!cutStart)return;cutEnd=canvasPoint(event);drawSlicePreview()};
stage.onpointerup=async event=>{
  if(!sliceMode||!cutStart)return;cutEnd=canvasPoint(event);const p0=cutStart,p1=cutEnd,joint=[(p0[0]+p1[0])/2,(p0[1]+p1[1])/2];cutStart=null;cutEnd=null;
  try{const entity=currentEntity(),part=$('#partSelect').value,animation=currentClip();const result=await api('slice',{collection_id:currentCollection().id,entity_id:entity.id,part,timeline_index:animation.timelines.findIndex(track=>track.object_type==='sprite'&&track.name===part),p0,p1,joint,overlap:5,cap_radius:9});state.project=result.project;Object.assign(state.assets,result.new_assets||{});sliceMode=false;sliceSource=null;$('#sliceMode').classList.remove('primary');stage.style.cursor='default';notify(`Created ${result.parts.join(' and ')}`);renderAll()}
  catch(error){notify(error.message,true);showSliceArt()}
};

function readData(file){return new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result).split(',')[1]);reader.onerror=reject;reader.readAsDataURL(file)})}
function download(data,name,mime='application/octet-stream'){const raw=atob(data),bytes=new Uint8Array(raw.length);for(let i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i);const url=URL.createObjectURL(new Blob([bytes],{type:mime})),link=document.createElement('a');link.href=url;link.download=name;link.click();setTimeout(()=>URL.revokeObjectURL(url),30000)}
$('#addCharacter').onclick=()=>$('#characterImage').click();
$('#characterImage').onchange=async event=>{const file=event.target.files[0];if(!file)return;const name=prompt('Character name',file.name.replace(/\.[^.]+$/,''));if(!name){event.target.value='';return}try{const result=await api('add_character',{name,png:await readData(file),collection:'characters'});state.project=result.project;Object.assign(state.assets,result.new_assets);selectedEntity=result.entity_id;selectedClip='idle';notify(`Added ${name} with idle, walk, attack, and die clips`);renderAll()}catch(error){notify(error.message,true)}event.target.value=''};
$('#addPart').onclick=()=>$('#partImage').click();
$('#partImage').onchange=async event=>{const file=event.target.files[0],entity=currentEntity();if(!file||!entity)return;const name=prompt('Part name',file.name.replace(/\.[^.]+$/,''));if(!name){event.target.value='';return}const bone=prompt(`Attach ${name} to which bone?\n${entity.bones.join(', ')}`,entity.bones[0]||'root');if(!bone){event.target.value='';return}try{const result=await api('add_part',{collection_id:currentCollection().id,entity_id:entity.id,name,bone,png:await readData(file)});state.project=result.project;Object.assign(state.assets,result.new_assets);renderAll();$('#partSelect').value=result.part;notify(`Added ${result.part} attached to ${bone}`)}catch(error){notify(error.message,true)}event.target.value=''};
$('#replacePart').onclick=()=>{if(currentEntity())$('#replacementImage').click()};
$('#replacementImage').onchange=async event=>{const file=event.target.files[0],entity=currentEntity(),part=$('#partSelect').value;if(!file||!entity||!part)return;try{const result=await api('replace_part_art',{collection_id:currentCollection().id,entity_id:entity.id,part,png:await readData(file)});state.project=result.project;Object.assign(state.assets,result.new_assets);notify(`Replaced art for ${part} across its animations`);renderAll()}catch(error){notify(error.message,true)}event.target.value=''};
$('#openProject').onchange=async event=>{const file=event.target.files[0];if(!file)return;try{refreshProject(await api('load_upload',{archive:await readData(file)}));notify(`Opened ${file.name}`)}catch(error){notify(error.message,true)}event.target.value=''};
$('#saveProject').onclick=async()=>{try{const result=await api('save');if(result.archive)download(result.archive,result.download);notify(result.path?`Saved ${result.path}`:'Downloaded editable .gmanim project')}catch(error){notify(error.message,true)}};
$('#newProject').onclick=async()=>{if(!confirm('Start a new project? Unsaved changes in this session will be replaced.'))return;try{refreshProject(await api('new_project'));notify('New project created')}catch(error){notify(error.message,true)}};
$('#editName').onclick=()=>{const name=prompt('Project name',state.project.name);if(name){state.project.name=name;renderAll()}};
$('#addClip').onclick=async()=>{const name=prompt('New clip name','special');if(!name)return;try{const result=await api('add_clip',{collection_id:currentCollection().id,entity_id:currentEntity().id,name});state.project=result.project;selectedClip=name;renderAll();notify(`Created ${name}`)}catch(error){notify(error.message,true)}};
$('#addBone').onclick=async()=>{const entity=currentEntity();if(!entity)return;const name=prompt('New child bone name','new_bone');if(!name)return;const parent=prompt(`Parent bone?\n${entity.bones.join(', ')}`,entity.bones[0]||'root');if(!parent)return;const length=Number(prompt('Display length in pixels','18'));if(!Number.isFinite(length)||length<=0)return;try{const result=await api('add_bone',{collection_id:currentCollection().id,entity_id:entity.id,name,parent,length});state.project=result.project;notify(`Added ${name} under ${parent}`);renderAll()}catch(error){notify(error.message,true)}};
$('#mapSelect').onchange=()=>{selectedMap=$('#mapSelect').value;fillInspector()};
$('#addMap').onclick=async()=>{const entity=currentEntity(),name=prompt('Character map name','alternate');if(!entity||!name)return;try{const result=await api('add_character_map',{collection_id:currentCollection().id,entity_id:entity.id,name});state.project=result.project;selectedMap=name;renderAll();notify(`Added character map ${name}`)}catch(error){notify(error.message,true)}};
$('#saveMap').onclick=async()=>{const entity=currentEntity();if(!entity||!selectedMap)return notify('Create or select a character map first.',true);try{const result=await api('set_character_map_entry',{collection_id:currentCollection().id,entity_id:entity.id,name:selectedMap,source:Number($('#mapSource').value),target:Number($('#mapTarget').value)});state.project=result.project;renderAll();notify(`Updated ${selectedMap}`)}catch(error){notify(error.message,true)}};
$('#previewMap').onclick=async()=>{const entity=currentEntity();if(!entity||!selectedMap)return notify('Create or select a character map first.',true);try{const active=state.project.settings.preview_maps?.[entity.id]||[],names=active.includes(selectedMap)?active.filter(name=>name!==selectedMap):[...active,selectedMap];const result=await api('set_preview_maps',{collection_id:currentCollection().id,entity_id:entity.id,names});state.project=result.project;renderAll()}catch(error){notify(error.message,true)}};
$('#removeMap').onclick=async()=>{const entity=currentEntity();if(!entity||!selectedMap)return;try{const result=await api('remove_character_map',{collection_id:currentCollection().id,entity_id:entity.id,name:selectedMap});state.project=result.project;selectedMap=null;renderAll();notify('Character map removed')}catch(error){notify(error.message,true)}};
async function exportAction(action){
  let args={};if(action==='export_yymps'){const template=prompt('Path to a GameMaker project (.yyp) to use as the export template');if(!template)return;args.template_project=template.trim()}
  const status=$('#statusText');status.textContent=action==='export_yymps'?'Building GameMaker package…':'Rendering animation export…';
  try{const result=await api(action,args);download(result.archive,result.download,action==='export_yymps'?'application/octet-stream':'application/zip');notify(action==='export_yymps'?`YYMPS ready · ${result.report.sprites} sprites, ${result.report.animations} animations`:`Export ready · ${result.report.frames||result.report.gifs?.length||0} frames`)}
  catch(error){notify(error.message,true)}finally{status.textContent='Ready'}
}
$('#exportPng').onclick=()=>exportAction('export_png');$('#exportGif').onclick=()=>exportAction('export_gif');$('#exportPackage').onclick=()=>exportAction('export_yymps');
$('#migrateScml').onclick=async()=>{const path=$('#scmlPath').value.trim();if(!path){notify('Enter the local path to the existing SCML file.',true);return}try{if(!confirm('Migrate this existing project into a new .gmanim session?'))return;refreshProject(await api('migrate_scml',{path}));notify('Project migrated. Save it as a .gmanim file.')}catch(error){notify(error.message,true)}};
$('#statusText').textContent='Loading animation project…';api('snapshot').then(value=>{refreshProject(value);$('#statusText').textContent='Ready'}).catch(error=>{$('#statusText').textContent='Load failed';notify(error.message,true)});
