// Reuses corrected, already-extracted sources. Never reads a PDF, never modifies the source repos.
// Output is private and deliberately outside the application's bundled resources.
import { readFileSync, readdirSync, writeFileSync, mkdirSync, existsSync, realpathSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const moduleRoot = resolve(process.argv[2] ?? join(root, '../declan-homebrew-classes'));
const importerRoot = resolve(process.argv[3] ?? join(root, '../dnd5e-pdf-importer'));
const privateRoot = resolve(process.argv[4] ?? join(root, '../declan-private-spells'));
const yaml = createRequire(join(importerRoot, 'emit/package.json'))('js-yaml');
const evidence = [];
function read(path) {
  const data = readFileSync(path, 'utf8');
  evidence.push({ file: realpathSync(path), sha256: createHash('sha256').update(data).digest('hex') });
  return yaml.load(data);
}
function files(path) {
  if (!existsSync(path)) return [];
  return readdirSync(path, { withFileTypes: true }).flatMap(e => e.isDirectory() ? files(join(path,e.name)) : /\.ya?ml$/.test(e.name) && !e.name.startsWith('_') ? [join(path,e.name)] : []);
}
const plain = value => String(value ?? '').replace(/@UUID\[[^\]]*\]\{([^}]*)\}/g,'$1').replace(/@(?:UUID|Embed)\[[^\]]*\]/g,'').replace(/\[\[([^\]]*)\]\]/g,'$1').replace(/<\/(?:p|div|h[1-6]|tr)>/g,'\n\n').replace(/<br\s*\/?>/g,'\n').replace(/<[^>]*>/g,'').replace(/&amp;/g,'&').replace(/&nbsp;/g,' ').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&#39;|&apos;/g,"'").replace(/&quot;/g,'"').replace(/[ \t]+/g,' ').replace(/\n\s+/g,'\n').trim();
const slug = name => name.toLowerCase().replace(/[’']/g,'').replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');
const normalize = name => name.toLowerCase().replace(/\s*\(ll\)/g,'').replace(/[’']/g,'').replace(/[^a-z0-9]/g,'');
const skillNames = {acr:'Acrobatics',ani:'Animal Handling',arc:'Arcana',ath:'Athletics',dec:'Deception',his:'History',ins:'Insight',itm:'Intimidation',inv:'Investigation',med:'Medicine',nat:'Nature',prc:'Perception',prf:'Performance',per:'Persuasion',rel:'Religion',slt:'Sleight of Hand',ste:'Stealth',sur:'Survival'};
const all = ['str','dex','con','int','wis','cha'];
const docs = files(join(moduleRoot, 'src/vessel')).map(read);
const byID = new Map(docs.map(d=>[d._id,d]));
const vessel = docs.find(d=>d.type==='class' && d.system.identifier==='vessel');
if (!vessel || vessel.system.spellcasting.ability !== 'cha') throw Error('Expected the corrected Charisma-based Vessel source.');
const scales = new Map(vessel.system.advancement.filter(a=>a.type==='ScaleValue').map(a=>[a.configuration.identifier,a.configuration.scale]));
function scaled(id,level) { const scale=scales.get(id)??{}; const key=Object.keys(scale).map(Number).filter(n=>n<=level).sort((a,b)=>b-a)[0]; return key ? scale[key].value : 0; }
function grantedFeatures(document) {
  return (document.system.advancement??[]).filter(a=>a.type==='ItemGrant' && a.level<=5).flatMap(a=>(a.configuration.items??[]).map(item=>{
    const source=byID.get(item.uuid.split('.').at(-1));
    if (!source) throw Error('Unresolved class feature '+item.uuid);
    return {id:source.system.identifier||slug(source.name),name:source.name,level:a.level,text:plain(source.system.description.value)};
  })).filter(f=>!f.id.includes('control'));
}
const standardRoot=join(importerRoot,'dnd5e/packs/_source');
const standardSpells=files(join(standardRoot,'spells24')).filter(p=>!p.includes('/vessel/')).map(read).filter(d=>d.type==='spell');
const privateSpells=files(join(privateRoot,'spells-src')).map(read).filter(d=>d.type==='spell');
const spellLookup=new Map();
for(const d of [...privateSpells,...standardSpells]) spellLookup.set(normalize(d.name),d); // revised 2024 versions win
const aliases={'Caustic Brew':"Tasha's Caustic Brew"};
const spells=new Map();
const diagnostics=[];
function spell(name, expectedLevel=1) {
  const id='spell.'+slug(aliases[name]??name);
  if(spells.has(id)) return id;
  const source=spellLookup.get(normalize(aliases[name]??name));
  if(!source) {
    diagnostics.push({type:'unresolved-spell',name,reason:'No standard version was found in the existing extracted sources. No homebrew substitution was invented.'});
    spells.set(id,{id,name,level:expectedLevel,text:'This spell reference needs source review before the build can pass its checks.',source:'Unresolved existing source reference',unavailableReason:'A standard spell source has not been resolved. This build needs source review.'});
  } else {
    spells.set(id,{id,name:source.name,level:source.system.level,text:plain(source.system.description.value),source:`${source.system.source?.custom || 'Foundry dnd5e source'} · ${source.system.source?.rules || 'legacy'} rules`});
  }
  return id;
}
const publicList=read(join(moduleRoot,'spell-lists-src/vessel-spells.yml'));
const allOldSpells=files(join(standardRoot,'spells')).map(read).filter(d=>d.type==='spell');
const oldByID=new Map([...allOldSpells,...standardSpells].map(d=>[d._id,d]));
const names=publicList.pages[0].system.spells.filter(x=>x.startsWith('Compendium.dnd5e.')).map(x=>oldByID.get(x.split('.').at(-1))?.name).filter(Boolean);
names.push(...publicList.pages[0].system.unlinkedSpells.filter(x=>x.system.level<=2).map(x=>x.name));
// Read the existing private list manifest, rather than maintaining another spell list by hand.
const manifestModule=await import(pathToFileURL(join(privateRoot,'scripts/build-vessel-spell-list.mjs')));
names.push(...manifestModule.APPROVED_VESSEL_SPELL_NAMES);
const spellIDs=[...new Set(names)].filter(name=>{const source=spellLookup.get(normalize(name));return source && source.system.level<=2;}).map(name=>spell(name));
const manifestPath=join(moduleRoot,'scripts/vessel/sealed-magic-manifest.mjs');
const manifest=readFileSync(manifestPath,'utf8');
evidence.push({file:manifestPath,sha256:createHash('sha256').update(manifest).digest('hex')});
const entries=[...manifest.matchAll(/manifestEntry\('([^']+)', (\d+), (?:'([^']+)'|"([^"]+)")\)/g)].map(m=>({subclass:m[1],level:Number(m[2]),name:m[3]??m[4]}));
// Cursed/Formless require additional nonreplaceable Aspect grants and choices.
// Do not certify them until the schema can represent those mechanics.
const supported=['the-trickster'];
diagnostics.push({type:'excluded-subclasses',names:['The Cursed','The Formless'],reason:'Additional subclass Aspect grants and replacement choices are not represented by schema v1. Cursed also references unresolved Flame Whip.'});
const subclasses=supported.map(id=>{
  const source=docs.find(d=>d.type==='subclass'&&d.system.identifier===id);
  const grants=entries.filter(e=>e.subclass===id&&e.level<=5);
  return {id,name:source.name,text:plain(source.system.description.value)||`Existing ${source.name} subclass progression. See granted features below.`,features:grantedFeatures(source),spells:[3,5].map(level=>({level,spellIDs:grants.filter(e=>e.level===level).map(e=>spell(e.name,level===3?1:2))}))};
});
const talents=files(join(moduleRoot,'aspects-src')).map(read).filter(d=>d.type==='feat'&&d.system.prerequisites.level<=5).flatMap(d=>{
  const id=d.system.identifier;const base={id,name:d.name,text:plain(d.system.description.value),minimumLevel:d.system.prerequisites.level,exclusiveGroup:id,skills:id==='uncanny-strength'?['Athletics']:[],requires:[]};
  return id==='striking-presence'?['Deception','Intimidation','Persuasion'].map(skill=>({...base,id:id+'-'+slug(skill),name:d.name+' · '+skill,skills:[skill]})):[base];
});
const featBase=(id,name,text,category,extras={})=>({id,name,text,category,minimumLevel:category==='origin'?1:4,abilityOptions:[],abilityPoints:0,hpPerLevel:0,initiativeProficiency:false,skills:[],abilityMinimums:{},...extras});
const bgDocs=files(join(privateRoot,'backgrounds-src')).map(read);
const tough=bgDocs.find(d=>d.name==='Tough');
const alert=read(join(standardRoot,'feats24/origin-feats/alert.yml'));
const asi=read(join(standardRoot,'feats24/general-feats/ability-score-improvement.yml'));
const featData=await import(pathToFileURL(join(privateRoot,'scripts/private-general-feat-data.mjs')));
const durable=featData.PRIVATE_2024_GENERAL_FEATS.find(f=>f.identifier==='durable');
const feats=[featBase('tough','Tough',plain(tough.system.description.value),'origin',{hpPerLevel:2}),featBase('alert','Alert',plain(alert.system.description.value),'origin',{initiativeProficiency:true}),featBase('ability-improvement',asi.name,plain(asi.system.description.value),'general',{abilityOptions:all,abilityPoints:2}),featBase('durable','Durable',durable.benefits.map(([a,b])=>a+'. '+b).join('\n\n'),'general',{abilityOptions:['con'],abilityPoints:1})];
const backgrounds=['Farmer','Criminal'].map(name=>{
  const d=bgDocs.find(x=>x.name===name); const adv=d.system.advancement;
  const traits=adv.filter(a=>a.type==='Trait').flatMap(a=>a.configuration.grants??[]);
  const boost=adv.find(a=>a.type==='AbilityScoreImprovement');
  return {id:slug(name),name,text:plain(d.system.description.value),abilities:all.filter(a=>!boost.configuration.locked.includes(a)),skills:traits.filter(t=>t.startsWith('skills:')).map(t=>skillNames[t.split(':')[1]]),tool:traits.filter(t=>t.startsWith('tool:')).map(t=>t.split(':').at(-1)).join(', '),originFeatID:name==='Farmer'?'tough':'alert',equipment:'See the background description. Equipment choices remain manual in this MVP.'};
});
const species=['dwarf','halfling'].map(id=>{const d=read(join(standardRoot,`origins24/species/${id}.yml`));return {id,name:d.name,text:plain(d.system.description.value),speed:d.system.movement.walk,hpPerLevel:id==='dwarf'?1:0,size:id==='dwarf'?'Medium':'Small'};});
const traits=vessel.system.advancement.filter(a=>a.type==='Trait');
const classSkills=traits.flatMap(a=>a.configuration.choices??[]).find(c=>c.pool.every(x=>x.startsWith('skills:')));
const pack={schemaVersion:1,id:'private.vessel',version:'0.1.1',name:'Vessel · private playtest',ruleset:'2024',isPrivate:true,
  attribution:'Private conversion of your corrected LaserLlama Vessel module and existing book/SRD sources. Original authors retain their content. No PDF was re-extracted.',
  coverageNotes:['Levels 1–5, single class, standard array, fixed-average HP. Trickster subclass; Dwarf and Halfling; Farmer and Criminal; ASI and Durable.', 'Known spells prefer existing standard 2024 versions; legacy expansion spells are retained where no revised version exists. Unique LaserLlama spell substitutions are not invented.', 'Cursed and Formless are excluded until their additional Aspect grants and choices are modeled. Cursed also has an unresolved Flame Whip reference.', 'Equipment, combat effects, spell preparation during play, multiclassing, cantrip replacement, and other classes/species/backgrounds are outside this slice.', 'Descriptions retain existing extraction artifacts; this converter does not silently rewrite the source prose.'],
  languages:['Dwarvish','Elvish','Giant','Gnomish','Goblin','Halfling','Orc','Draconic','Common Sign Language'],
  species,backgrounds,feats,spells:[...spells.values()],classes:[{id:'vessel',name:vessel.name,summary:'A sealed spirit. A borrowed power. A life of your own.',hitDie:Number(vessel.system.hd.denomination.slice(1)),primaryAbility:'cha',spellAbility:'cha',saves:traits.flatMap(a=>a.configuration.grants??[]).filter(x=>x.startsWith('saves:')).map(x=>x.split(':')[1]),skillCount:classSkills.count,skillPool:classSkills.pool.map(x=>skillNames[x.split(':')[1]]),subclassLevel:3,talentLabel:'Unsealed Aspects',features:grantedFeatures(vessel),talents,subclasses,progression:[1,2,3,4,5].map(level=>({level,talents:scaled('aspects-known',level),cantrips:scaled('cantrips-known',level),spells:scaled('spells-known',level),slots:scaled('spell-slots',level),slotLevel:scaled('slot-level',level),improvement:level===4})),spellIDs:[...new Set(spellIDs)],equipment:'The corrected class source has no starting-equipment entries. Choose equipment with your GM; this app does not certify inventory.',armorFormula:'vessel-mantle'}]};
const destination=join(root,'PrivatePacks');mkdirSync(destination,{recursive:true});
writeFileSync(join(destination,'vessel-pack.json'),JSON.stringify(pack,null,2)+'\n');
writeFileSync(join(destination,'conversion-report.json'),JSON.stringify({generatedAt:new Date().toISOString(),sourceCount:evidence.length,classes:pack.classes.length,spells:pack.spells.length,diagnostics,evidence},null,2)+'\n');
console.log(`Converted Vessel without PDF extraction: ${pack.spells.length} spells, ${talents.length} aspect choices, ${subclasses.length} subclasses. ${diagnostics.length} coverage diagnostics.`);
