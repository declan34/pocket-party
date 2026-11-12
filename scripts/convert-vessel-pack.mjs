// Reuses corrected, already-extracted sources. Never reads a PDF, never modifies the source repos.
// Output is private and deliberately outside the application's bundled resources.
import { readFileSync, readdirSync, writeFileSync, mkdirSync, existsSync, realpathSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

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
// LL and standard records are distinct sources, never implicit aliases.
const normalize = name => name.toLowerCase().replace(/[’']/g,'').replace(/[^a-z0-9]/g,'');
const skillNames = {acr:'Acrobatics',ani:'Animal Handling',arc:'Arcana',ath:'Athletics',dec:'Deception',his:'History',ins:'Insight',itm:'Intimidation',inv:'Investigation',med:'Medicine',nat:'Nature',prc:'Perception',prf:'Performance',per:'Persuasion',rel:'Religion',slt:'Sleight of Hand',ste:'Stealth',sur:'Survival'};
const all = ['str','dex','con','int','wis','cha'];
const docs = files(join(moduleRoot, 'src/vessel')).map(read);
const byID = new Map(docs.map(d=>[d._id,d]));
const vessel = docs.find(d=>d.type==='class' && d.system.identifier==='vessel');
if (!vessel || vessel.system.spellcasting.ability !== 'cha') throw Error('Expected the corrected Charisma-based Vessel source.');
const scales = new Map(vessel.system.advancement.filter(a=>a.type==='ScaleValue').map(a=>[a.configuration.identifier,a.configuration.scale]));
function scaled(id,level) { const scale=scales.get(id)??{}; const key=Object.keys(scale).map(Number).filter(n=>n<=level).sort((a,b)=>b-a)[0]; return key ? scale[key].value : 0; }
function grantedFeatures(document) {
  return (document.system.advancement??[]).filter(a=>a.type==='ItemGrant' && a.level<=20).flatMap(a=>(a.configuration.items??[]).map(item=>{
    const source=byID.get(item.uuid.split('.').at(-1));
    if (!source) throw Error('Unresolved class feature '+item.uuid);
    return {id:source.system.identifier||slug(source.name),name:source.name,level:a.level,text:plain(source.system.description.value)};
  })).filter(f=>f.id!=='archon-form-control');
}
const standardRoot=join(importerRoot,'dnd5e/packs/_source');
const standardSpells=files(join(standardRoot,'spells24')).filter(p=>!p.includes('/vessel/')).map(read).filter(d=>d.type==='spell');
const allOldSpells=files(join(standardRoot,'spells')).map(read).filter(d=>d.type==='spell');
const privateSpells=files(join(privateRoot,'spells-src')).map(read).filter(d=>d.type==='spell');
const spellLookup=new Map();
for(const d of [...allOldSpells,...privateSpells,...standardSpells]) {
  if (!/\(ll\)/i.test(d.name)) spellLookup.set(normalize(d.name),d); // revised 2024 versions win
}
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
const oldByID=new Map([...allOldSpells,...standardSpells].map(d=>[d._id,d]));
const names=publicList.pages[0].system.spells.filter(x=>x.startsWith('Compendium.dnd5e.')).map(x=>oldByID.get(x.split('.').at(-1))?.name).filter(Boolean);
names.push(...publicList.pages[0].system.unlinkedSpells.filter(x=>x.system.level<=5).map(x=>x.name));
const moduleSpellDocs=files(join(moduleRoot,'spells-src')).map(read).filter(d=>d.type==='spell');
const moduleSpellByID=new Map(moduleSpellDocs.map(d=>[d._id,d]));
const unresolvedListIDs=[];
for(const uuid of publicList.pages[0].system.spells.filter(x=>!x.startsWith('Compendium.dnd5e.'))) {
  const source=moduleSpellByID.get(uuid.split('.').at(-1));
  if(!source) throw Error('Unresolved source spell-list UUID '+uuid);
  if(source.system.level<=5) unresolvedListIDs.push(spell(source.name,source.system.level));
}
// Read the existing private list manifest, rather than maintaining another spell list by hand.
const manifestModule=await import(pathToFileURL(join(privateRoot,'scripts/build-vessel-spell-list.mjs')));
names.push(...manifestModule.APPROVED_VESSEL_SPELL_NAMES);
const spellIDs=[...new Set([...names.filter(name=>{const source=spellLookup.get(normalize(name));return source && source.system.level<=5;}).map(name=>spell(name)),...unresolvedListIDs])];
const manifestPath=join(moduleRoot,'scripts/vessel/sealed-magic-manifest.mjs');
const manifest=readFileSync(manifestPath,'utf8');
evidence.push({file:manifestPath,sha256:createHash('sha256').update(manifest).digest('hex')});
const {SEALED_MAGIC_ENTRIES: entries}=await import(pathToFileURL(manifestPath));
const supported=['the-ascended','the-cataclysm','the-cursed','the-fallen','the-formless','the-trickster'];
const subclasses=supported.map(id=>{
  const source=docs.find(d=>d.type==='subclass'&&d.system.identifier===id);
  const grants=entries.filter(e=>e.subclass===id&&e.vesselLevel<=20);
  return {id,name:source.name,text:plain(source.system.description.value)||`Existing ${source.name} subclass progression. See granted features below.`,features:grantedFeatures(source),spells:[],capabilities:{edition:'2024',grants:grants.map(e=>({id:e.key,kind:'spell',target:spell(e.name,({3:1,5:2,9:3,13:4,17:5})[e.vesselLevel]),level:e.vesselLevel,...(e.affinity?{condition:{kind:'selection',key:'affinity-'+e.affinity}}:{})}))}};
});
const aspectSources=files(join(moduleRoot,'aspects-src')).map(read).filter(d=>d.type==='feat');
const talents=aspectSources.flatMap(d=>{
  const id=d.system.identifier;
  const dependencies=aspectSources.filter(other=>other!==d&&(d.system.requirements??'').includes(other.name)).map(other=>other.system.identifier);
  const base={id,name:d.name,text:plain(d.system.description.value),minimumLevel:d.system.prerequisites.level,exclusiveGroup:id==='minor-magick'?'':id,skills:id==='uncanny-strength'?['Athletics']:[],requires:dependencies};
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
feats.find(f=>f.id==='ability-improvement').repeatable=true;
const backgrounds=['Farmer','Criminal'].map(name=>{
  const d=bgDocs.find(x=>x.name===name); const adv=d.system.advancement;
  const traits=adv.filter(a=>a.type==='Trait').flatMap(a=>a.configuration.grants??[]);
  const boost=adv.find(a=>a.type==='AbilityScoreImprovement');
  return {id:slug(name),name,text:plain(d.system.description.value),abilities:all.filter(a=>!boost.configuration.locked.includes(a)),skills:traits.filter(t=>t.startsWith('skills:')).map(t=>skillNames[t.split(':')[1]]),tool:traits.filter(t=>t.startsWith('tool:')).map(t=>t.split(':').at(-1)).join(', '),originFeatID:name==='Farmer'?'tough':'alert',equipment:'See the background description. Equipment choices remain manual in this MVP.'};
});
const species=['dwarf','halfling'].map(id=>{const d=read(join(standardRoot,`origins24/species/${id}.yml`));return {id,name:d.name,text:plain(d.system.description.value),speed:d.system.movement.walk,hpPerLevel:id==='dwarf'?1:0,size:id==='dwarf'?'Medium':'Small'};});
const traits=vessel.system.advancement.filter(a=>a.type==='Trait');
const classSkills=traits.flatMap(a=>a.configuration.choices??[]).find(c=>c.pool.every(x=>x.startsWith('skills:')));
const reviewPath=join(root,'PrivatePacks/vessel-source-review.json');
if (!existsSync(reviewPath)) throw Error('Private source review is required; do not infer corrections from truncated extraction.');
const sourceReview=read(reviewPath);
const pred=(kind,key)=>({kind,key});
const together=(...children)=>({kind:'all',children});
const cloaked={kind:'any',children:[pred('configuration','cloak'),pred('configuration','archon')]};
const unarmored=together(cloaked,pred('configuration','no-armor-shield'));
const grant=(id,kind,extras={})=>({id,kind,...extras});
const note=(id,text,condition)=>grant(id,'trait',{text,...(condition?{condition}:{})});
const aspects=talents.map(t=>({id:t.id,name:t.name,text:t.text,exclusiveGroup:t.exclusiveGroup,repeatable:t.id==='minor-magick',prerequisite:t.requires.length?together({kind:'level',minimum:t.minimumLevel},...t.requires.map(id=>pred('selection',id))):{kind:'level',minimum:t.minimumLevel},grants:[note(t.id+'-rules',t.text)]}));
for(const a of aspects) {
  if(a.id==='uncanny-strength') a.grants=[grant('uncanny-training','proficiency',{target:'Athletics',rank:'proficient'}),grant('uncanny-ability','skillAbility',{target:'Athletics',ability:'cha',condition:cloaked})];
  if(a.id.startsWith('striking-presence-')) {
    const skill=talents.find(t=>t.id===a.id).skills[0];
    a.grants=[grant(a.id+'-training','proficiency',{target:skill,rank:'proficient'}),note(a.id+'-advantage',`Advantage on ${skill} checks while cloaked.`,cloaked)];
  }
  if(a.id==='opalescent-armor') a.grants=[note('opalescent-resistance','Resistance to bludgeoning, piercing and slashing damage; silvered weapons bypass this resistance.',pred('configuration','fortified')),grant('opalescent-speed','speed',{value:{base:-10},condition:pred('configuration','fortified')})];
  if(a.id==='spirit-sense') a.grants=[note('spirit-sense-rules',a.text,cloaked)];
  if(a.id==='iridescent-shield') a.grants.push(grant('iridescent-reduction','trait',{text:'Iridescent Shield reaction damage reduction',value:{levelMultiplier:1,abilities:['cha']},condition:cloaked}));
  if(a.id==='ethereal-tendril') a.grants.push(grant('tendril-strength','trait',{text:'Tendril uses your Charisma score as Strength; reach is 10 ft or 20 ft while cloaked.'}));
  if(a.id==='minor-magick') a.grants.push(grant('minor-magick-use','resource',{target:'Minor Magick (distinct Sealed Magic spell per use)',value:{base:1},recovery:'long rest'}));
  if(a.id==='primeval-thirst') a.grants.push(grant('primeval-thirst-uses','resource',{target:'Primeval Thirst',value:{abilities:['cha'],minimum:1},recovery:'long rest'}));
  if(a.id==='lord-of-spirits') a.grants.push(grant('lord-of-spirits-uses','resource',{target:'Lord of Spirits',value:{base:1},recovery:'long rest'}));
  if(a.id==='evoke-spirit') a.grants.push(grant('evoke-spirit-spell','spell',{target:spell('Conjure Familiar LL'),spellMode:'ritual'}));
  if(a.id==='twilight-steps') a.grants.push(grant('twilight-steps-spell','spell',{target:spell('Spectral Passage LL',5),spellMode:'atWill'}));
}
const wizardPage=read(join(standardRoot,'content24/chapter-7/spells.yml')).pages.find(p=>p.system?.identifier==='wizard');
if(!wizardPage) throw Error('Verified Wizard journal page missing');
const revisedByID=new Map(standardSpells.map(d=>[d._id,d]));
const wizardIDs=wizardPage.system.spells.map(uuid=>{
  const d=revisedByID.get(uuid.split('.').at(-1));
  if(!d) throw Error('Unresolved Wizard journal UUID '+uuid);
  return d;
}).filter(d=>d.system.level>0&&d.system.level<=6).map(d=>spell(d.name));
// Materialize all source ScaleValue steps; the exported engine contract never extrapolates.
const levels=Array.from({length:20},(_,i)=>i+1);
const counts=levels.map(l=>scaled('spells-known',l)), maximum=levels.map(l=>scaled('slot-level',l));
const cantripCounts=levels.map(l=>scaled('cantrips-known',l));
const aspectCounts=levels.map(l=>scaled('aspects-known',l));
const from=level=>levels.map(l=>l>=level?1:0);
const zeros=levels.map(()=>0);
const knownIDs=spellIDs.filter(id=>spells.get(id).level>0);
const cantripIDs=spellIDs.filter(id=>spells.get(id).level===0);
const configurations=[
  {id:'cloak',name:'Spirit Mantle',text:'Declared cloak state; casting requires the cloak, but knowledge is retained when inactive.'},
  {id:'no-armor-shield',name:'No armor or shield',text:'Declared condition only; equipment state arrives in I5.'},
  {id:'archon',name:'Archon Form',text:'Includes Spirit Mantle. Expenditure and transformation duration are not simulated.',prerequisite:{kind:'level',minimum:3}},
  {id:'fortified',name:'Fortified Opalescent Armor',text:'Optional fortification when cloaking.',prerequisite:together(cloaked,pred('selection','opalescent-armor'))}
];
for(const [id,aspect] of [['dire-stature-active','dire-stature'],['colossal-archon-active','colossal-archon']]) configurations.push({id,name:aspect==='dire-stature'?'Larger Archon':'Huge Archon',text:'Declared transformation size, if space permits.',exclusiveGroup:'archon-stature',prerequisite:together(pred('configuration','archon'),pred('selection',aspect))});
for(const [id,size,bonus] of [['dire-stature-active','Large',1],['colossal-archon-active','Huge',2]]) {
  const aspect=aspects.find(a=>a.id===(bonus===1?'dire-stature':'colossal-archon'));
  aspect.grants.push(grant(id+'-size','size',{target:size,condition:pred('configuration',id)}),grant(id+'-ac','armorBonus',{value:{base:bonus},condition:together(unarmored,pred('configuration',id))}),grant(id+'-reach','trait',{text:'Bonus melee reach (ft)',value:{base:bonus*5},condition:pred('configuration',id)}));
}
aspects.find(a=>a.id==='aether-wings').grants.push(grant('aether-wings-flight','trait',{text:'fly speed (ft)',value:{base:60},condition:together(cloaked,{kind:'not',children:[pred('configuration','fortified')]})}),grant('aether-wings-flight-fortified','trait',{text:'fly speed (ft)',value:{base:50},condition:together(cloaked,pred('configuration','fortified'))}));
const classCapabilities={edition:'2024',configurations,
  groups:[{id:'aspects',name:'Unsealed Aspects',counts:aspectCounts,replacementLimits:levels.map((l,i)=>i>0&&aspectCounts[i]>aspectCounts[i-1]?1:0),options:aspects}],
  grants:[grant('ethereal-armor','armorFormula',{value:{base:10,abilities:['con','cha']},condition:unarmored}),
    grant('archon-uses','resource',{level:3,target:'Archon Form',value:{base:1},recovery:'short or long rest'}),
    note('casting-availability','Casting Vessel spells requires Spirit Mantle, a free hand where required, and any consumed or costly components.'),
    note('iridescent-strike-d6','Iridescent Strike: Charisma attack, 1d6 + Charisma radiant damage.',together(cloaked,{kind:'not',children:[{kind:'level',minimum:5}]})),
    {...note('iridescent-strike-d8','Iridescent Strike: Charisma attack, 1d8 + Charisma radiant damage; extra attack and spell-action bonus strike.',cloaked),level:5},
    grant('archon-temporary-hp','trait',{level:3,text:'Temporary HP granted on transformation (current amount untracked)',value:{levelMultiplier:2},condition:pred('configuration','archon')})],
  casting:[{id:'vessel-cantrips',name:'Vessel cantrips',mode:'known',ability:'cha',spellIDs:cantripIDs,counts:cantripCounts,maximumSpellLevels:zeros,replacementLimits:zeros},
    {id:'vessel-known',name:'Vessel spells known',mode:'known',ability:'cha',spellIDs:knownIDs,counts,maximumSpellLevels:maximum,replacementLimits:from(2),condition:{kind:'not',children:[pred('subclass','the-ascended')]}}]};
classCapabilities.grants=classCapabilities.grants.filter(g=>!g.id.startsWith('iridescent-strike-d'));
classCapabilities.grants.push(grant('iridescent-die','trait',{text:'Iridescent Strike die sides',value:{table:[6,6,6,6,8,8,8,8,8,8,10,10,10,10,10,10,12,12,12,12]},condition:cloaked}),
  grant('extra-attack-count','trait',{level:5,text:'Attacks per Attack action',value:{base:2},condition:{kind:'not',children:[together(pred('subclass','the-cursed'),pred('configuration','archon'),{kind:'level',minimum:20})]}}),
  grant('primeval-will-uses','resource',{level:10,target:'Primeval Will',value:{abilities:['cha'],minimum:1},recovery:'long rest'}));
const bySubclass=new Map(subclasses.map(s=>[s.id,s.capabilities]));
bySubclass.get('the-ascended').casting=[{id:'ascended-prepared',name:'Ascended preparation',mode:'prepared',ability:'cha',spellIDs:[...new Set([...knownIDs,...wizardIDs.filter(id=>spells.get(id).level<=5)])],counts:counts.map((n,i)=>i<2?0:n),maximumSpellLevels:maximum,text:'Prepare from Vessel or verified Wizard list; prepared rituals may be cast as rituals. Sealed Magic is additional.'}];
for(const [tier,unlock] of [[5,15],[6,20]]) {
  bySubclass.get('the-ascended').casting.push({id:'ascended-arcanum-'+tier,name:'Ascended Arcanum '+tier,mode:'limited',ability:'cha',spellIDs:wizardIDs.filter(id=>spells.get(id).level===tier),counts:from(unlock),maximumSpellLevels:levels.map(()=>tier),replacementLimits:zeros,text:'One selected Wizard spell, cast once per long rest without a slot.'});
  bySubclass.get('the-ascended').grants.push(grant('ascended-arcanum-'+tier+'-uses','resource',{level:unlock,target:'Ascended Arcanum '+tier,value:{base:1},recovery:'long rest'}));
}
for(const g of bySubclass.get('the-ascended').grants) if(g.kind==='spell') g.spellMode='prepared';
bySubclass.get('the-ascended').grants.push(note('ascended-rituals','Prepared spells may be cast as rituals; Ascended Magic is always prepared and does not consume preparation choices.'));
bySubclass.get('the-cataclysm').groups=[{id:'affinity',name:'Elemental Affinity',counts:from(3),locked:true,options:['air','earth','fire','water'].map((element,i)=>({id:'affinity-'+element,name:element,text:'Select the bound elemental affinity.',grants:[note('affinity-resistance-'+element,'Resistance to '+['thunder','bludgeoning','fire','cold'][i]+'; Iridescent Strikes may deal this damage type.')]}))}];
bySubclass.get('the-cursed').groups=[{id:'cursed-bonus',name:'Malignant Aura bonus Aspect',counts:from(3),locked:true,requiredOptionIDs:aspects.filter(a=>a.id.startsWith('striking-presence-')).map(a=>a.id),waiveRequiredFamilyIfOwned:true,options:aspects}];
bySubclass.get('the-cursed').groups[0].exclusiveGroupExceptions=['striking-presence'];
bySubclass.get('the-formless').groups=[{id:'formless-bonus',name:'Amorphous Shape bonus Aspect',counts:from(3),locked:true,requiredOptionID:'ethereal-tendril',options:aspects}];
bySubclass.get('the-fallen').groups=[{id:'fallen-bonus',name:'Heavenly Zeal bonus Aspect',counts:from(15),locked:true,requiredOptionID:'aether-wings',requirementTiming:'acquisition',options:aspects}];
// Source: subclass-features/the-cursed/malignant-aura.yml and
// subclass-features/the-formless/amorphous-shape.yml; verified original page 14.
for(const id of ['the-cursed','the-formless']) bySubclass.get(id).groups[0].requirementTiming='acquisition';
bySubclass.get('the-formless').grants.push(note('amorphous-shape','Can move through a one-inch gap without squeezing; worn and carried objects do not change.',cloaked));
bySubclass.get('the-fallen').grants.push(grant('fallen-insight','proficiency',{target:'Insight',rank:'proficient'}),grant('fallen-insight-bonus','skillBonus',{target:'Insight',value:{abilities:['cha']},condition:cloaked}),note('fallen-training','Proficient with all martial weapons.'),note('fallen-wrath','Melee weapon attacks may use Charisma, deal radiant damage, and count as Iridescent Strikes.',cloaked));
bySubclass.get('the-trickster').grants.push(note('trickster-at-will','Disguise Self at will without a slot, and mimic heard sounds and voices.',cloaked));
bySubclass.get('the-trickster').grants.push(grant('trickster-free-disguise','spell',{target:spell('Disguise Self'),spellMode:'atWill',condition:cloaked}));
const archon=pred('configuration','archon');
const highFeature=(subclass,id,level)=>{
  const source=docs.find(d=>d.system?.identifier===id);
  if(!source) throw Error('Missing high-level feature '+id);
  bySubclass.get(subclass).grants.push({...note(id+'-rules',plain(source.system.description.value)),level});
};
for(const [sub,id,l] of [['the-ascended','ancient-knowledge',6],['the-cataclysm','elder-power',6],['the-cataclysm','cataclysmic-eruption',15],['the-cursed','hellfire',6],['the-fallen','condemnation',6],['the-formless','drain-vitality',6],['the-formless','consume-strike',15],['the-trickster','illusory-strikes',6],['the-trickster','fey-retribution',15]]) highFeature(sub,id,l);
const apexEruption=together(archon,{kind:'level',minimum:20});
bySubclass.get('the-cataclysm').grants.push(grant('cataclysmic-eruption-uses','resource',{level:15,target:'Cataclysmic Eruption',value:{abilities:['cha'],minimum:1},recovery:'long rest',condition:{kind:'not',children:[apexEruption]}}),note('cataclysmic-eruption-at-will','Cataclysmic Eruption: at will in Archon Form',apexEruption));
bySubclass.get('the-cursed').grants.push(grant('cursed-apex-attacks','trait',{level:20,text:'Attacks per Attack action',value:{base:3},condition:archon}),{...note('cursed-apex-immunities','Immune to fire and poison damage; Charmed, Frightened, Poisoned.',archon),level:20});
bySubclass.get('the-formless').grants.push(grant('drain-vitality-dice','trait',{level:6,text:'Drain Vitality d8 count',value:{table:[0,0,0,0,0,2,2,2,3,3,3,3,4,4,4,4,5,5,5,6]},condition:archon}));
for(const [sub,id] of [['the-ascended','archmage-reborn'],['the-formless','primordial-hunger'],['the-cataclysm','cataclysm-reborn']]) {
  const reviewed=sourceReview.resolved.find(r=>r.id===id);
  if(!reviewed) throw Error('Missing reviewed source correction '+id);
  bySubclass.get(sub).grants.push({...note(id+'-reviewed',reviewed.mechanics,archon),level:20});
  const feature=subclasses.find(s=>s.id===sub).features.find(f=>f.id===id);
  if(feature) feature.text=reviewed.mechanics;
}
// Higher subclass clauses are interleaved in the original extraction. Preserve
// their exact source evidence, while exposing build facts separately above.
const intermediate=read(join(importerRoot,'work/vessel/intermediate.json'));
function findSlug(value,id) { if(!value||typeof value!=='object') return; if(value.slug===id)return value; for(const child of Object.values(value)){const found=findSlug(child,id);if(found)return found;} }
for(const [sub,sourceID,title,level,next] of [
  ['the-cursed','hellfire','Dark Sacrifice',15,'Lord of Darkness'],
  ['the-cursed','hellfire','Lord of Darkness',20,'The Fallen'],
  ['the-fallen','divine-wrath','Heavenly Zeal',15,'Divine Avenger'],
  ['the-fallen','divine-wrath','Divine Avenger',20,'The Formless'],
  ['the-trickster','fey-retribution','Lord of Mischief',20,'AC Bonus']]) {
  const source=findSlug(intermediate,sourceID);const text=plain(source?.descriptionHtml?.value);
  const start=text.indexOf(title), end=text.indexOf(next,start+title.length);
  if(start<0) throw Error('Unresolved interleaved source clause '+title);
  const clause=text.slice(start,end<0?undefined:end).trim();
  subclasses.find(s=>s.id===sub).features.push({id:slug(title),name:title,level,text:clause});
  bySubclass.get(sub).grants.push({...note(slug(title)+'-source',clause,level===20?archon:undefined),level});
}
const profilesPath=join(moduleRoot,'scripts/vessel/rules.mjs');
const profilesBytes=readFileSync(profilesPath,'utf8');
evidence.push({file:profilesPath,sha256:createHash('sha256').update(profilesBytes).digest('hex')});
const {ARCHON_PROFILES}=await import(pathToFileURL(profilesPath));
for(const profile of Object.values(ARCHON_PROFILES)) {
  const source=read(join(moduleRoot,'archon-src',profile.profile+'-archon.yml'));
  if(source._id!==profile.actorId) throw Error('Archon source identity mismatch');
  const condition=together(pred('configuration','archon'),...(profile.affinity?[pred('selection','affinity-'+profile.affinity)]:[]));
  const grants=bySubclass.get(profile.subclass).grants;
  // Flat actor AC, HP and abilities are placeholders. Only runtime AC bonus is authoritative.
  grants.push(grant(profile.profile+'-defense','armorFormula',{value:{base:10+profile.acBonus,abilities:['con','cha']},condition:together(condition,unarmored)}));
  for(const [key,skill] of Object.entries(source.system.skills??{})) if(skill.value>0) grants.push(grant(profile.profile+'-skill-'+key,'proficiency',{target:skillNames[key],rank:skill.value===2?'expertise':'proficient',condition}));
  const movement=source.system.attributes.movement;
  grants.push(grant(profile.profile+'-walking-speed','speedBase',{value:{base:movement.walk},condition}));
  if(source.system.traits.size!=='med') throw Error('Archon size growth requires review for non-Medium source profile');
  grants.push(grant(profile.profile+'-size','size',{target:'Medium',condition:together(condition,{kind:'not',children:[{kind:'any',children:[pred('configuration','dire-stature-active'),pred('configuration','colossal-archon-active')]}]})}));
  const languageNames={primordial:'Primordial',auran:'Auran',terran:'Terran',ignan:'Ignan',aquan:'Aquan',infernal:'Infernal',celestial:'Celestial',sylvan:'Sylvan'};
  for(const language of source.system.traits.languages?.value??[]) {
    if(!languageNames[language]) throw Error('Unresolved source language identity: '+language);
    grants.push(grant(profile.profile+'-language-'+language,'language',{target:languageNames[language],condition}));
  }
  if(source.system.traits.languages?.custom || Object.keys(source.system.traits.languages?.communication??{}).length) {
    diagnostics.push({type:'unsupported-language-communication',profile:profile.profile,reason:'Custom language or communication semantics require source review.'});
    grants.push(grant(profile.profile+'-language-review','unsupported',{text:'Custom language or communication semantics require source review.',condition}));
  }
  for(const [mode,rate] of Object.entries(movement)) if(['fly','climb','swim','burrow'].includes(mode)&&rate>0) {
    const movementCondition=mode==='fly'?together(condition,{kind:'not',children:[pred('selection','aether-wings')]}):condition;
    const value=profile.profile==='ascended'&&mode==='fly'?{table:levels.map(l=>l===20?30:rate)}:{base:rate};
    const slowed=value.table?{table:value.table.map(n=>Math.max(0,n-10))}:{base:Math.max(0,rate-10)};
    grants.push(grant(profile.profile+'-'+mode,'trait',{text:mode+' speed (ft)',value,condition:together(movementCondition,{kind:'not',children:[pred('configuration','fortified')]})}));
    grants.push(grant(profile.profile+'-'+mode+'-fortified','trait',{text:mode+' speed (ft)',value:slowed,condition:together(movementCondition,pred('configuration','fortified'))}));
  }
  const senses=source.system.attributes.senses;
  const facts=[source.name+'; '+source.system.details.type.value, movement.hover?'Hover':null,
    ...Object.entries(senses.ranges??{}).filter(([,rate])=>rate>0).map(([sense,rate])=>`${sense}: ${rate} ft`),senses.special,
    ...[['Resistance',source.system.traits.dr],['Damage immunity',source.system.traits.di],['Condition immunity',source.system.traits.ci]].flatMap(([label,data])=>data?.value?.length?[label+': '+data.value.join(', ')]:[])].filter(Boolean);
  grants.push(note(profile.profile+'-profile',facts.join('; '),condition));
  if(profile.profile==='formless') grants.push(grant('formless-pseudopod-count','trait',{text:'Additional pseudopods',value:{abilities:['cha'],minimum:0},condition}));
  for(const item of source.items??[]) grants.push(note(profile.profile+'-'+item.system.identifier,plain(item.system.description.value),condition));
}
const classFeatures=grantedFeatures(vessel);
classFeatures.find(f=>f.id==='unchained-power').text=sourceReview.resolved.find(r=>r.id==='unchained-power').mechanics;
const progression=levels.map(level=>({level,talents:scaled('aspects-known',level),cantrips:scaled('cantrips-known',level),spells:scaled('spells-known',level),slots:scaled('spell-slots',level),slotLevel:scaled('slot-level',level),improvement:[4,8,12,16,19].includes(level)}));
const pack={schemaVersion:2,capabilities:{version:1,required:['choices','modifiers','casting','resources','traits','proficiencies','configuration','languages']},id:'private.vessel',version:'0.4.0',name:'Vessel · private playtest',ruleset:'2024',isPrivate:true,
  attribution:'Private conversion of your corrected LaserLlama Vessel module and existing book/SRD sources. Original authors retain their content. No PDF was re-extracted.',
  coverageNotes:['Levels 1–20, single class, standard array, fixed-average HP. Six supplied subclasses and all 24 Aspects; unresolved source references block affected builds.', 'Standard spells only: revised versions preferred, exact legacy fallback where present. LL spell identities are not silently substituted.', 'Equipment, combat expenditure and lifecycle, multiclassing and heterogeneous spell pools remain outside this slice.', 'Inherited descriptions may contain extraction artifacts; verified mechanical corrections are recorded in the private report.'],
  languages:['Dwarvish','Elvish','Giant','Gnomish','Goblin','Halfling','Orc','Draconic','Common Sign Language'],
  species,backgrounds,feats,spells:[...spells.values()],classes:[{id:'vessel',name:vessel.name,summary:'A sealed spirit. A borrowed power. A life of your own.',hitDie:Number(vessel.system.hd.denomination.slice(1)),primaryAbility:'cha',spellAbility:'cha',saves:traits.flatMap(a=>a.configuration.grants??[]).filter(x=>x.startsWith('saves:')).map(x=>x.split(':')[1]),skillCount:classSkills.count,skillPool:classSkills.pool.map(x=>skillNames[x.split(':')[1]]),subclassLevel:3,talentLabel:'Unsealed Aspects',features:classFeatures,talents,subclasses,progression,spellIDs:[...new Set(spellIDs)],equipment:'Starting equipment choices are present in Mortal Vessel prose. Review those choices with your GM; structured inventory and armor tracking await I5.',armorFormula:'unarmored',capabilities:classCapabilities}]};
const destination=join(root,'PrivatePacks');mkdirSync(destination,{recursive:true});
writeFileSync(join(destination,'vessel-pack.json'),JSON.stringify(pack,null,2)+'\n');
const moduleInfo=read(join(moduleRoot,'module.json'));
const revision=execFileSync('git',['-C',moduleRoot,'rev-parse','HEAD'],{encoding:'utf8'}).trim();
writeFileSync(join(destination,'conversion-report.json'),JSON.stringify({generatedAt:new Date().toISOString(),module:{version:moduleInfo.version,revision},sourceReview,wizardPage:{id:wizardPage._id,policy:'Explicit revised Wizard journal membership'},sourceCount:evidence.length,classes:pack.classes.length,spells:pack.spells.length,diagnostics,evidence},null,2)+'\n');
console.log(`Converted Vessel without PDF extraction: ${pack.spells.length} spells, ${talents.length} aspect choices, ${subclasses.length} subclasses. ${diagnostics.length} coverage diagnostics.`);
