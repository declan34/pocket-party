// Original fictional content only. This fixture exercises the public format without shipping book text.
import { writeFileSync } from 'node:fs';
const all = ['str', 'dex', 'con', 'int', 'wis', 'cha'];
const feature = (id, name, level, text) => ({ id, name, level, text });
const talent = (id, name, text, skills = [], minimumLevel = 1) => ({ id, name, text, skills, minimumLevel, exclusiveGroup: id, requires: [] });
const feat = (id, name, text, category = 'origin', extras = {}) => ({ id, name, text, category, minimumLevel: category === 'origin' ? 1 : 4, abilityOptions: [], abilityPoints: 0, hpPerLevel: 0, initiativeProficiency: false, skills: [], abilityMinimums: {}, ...extras });
const spells = [
  ['ember-script', 'Ember Script', 0, 'Trace a brief, harmless message in the air with warm sparks. It fades when you finish reading it aloud.'],
  ['little-beacon', 'Little Beacon', 0, 'A small floating light follows your hand. It illuminates a forgotten corner without giving off heat.'],
  ['paper-bird', 'Paper Bird', 0, 'Fold a scrap of paper into a bird that glides to a creature you can see, carrying a written message.'],
  ['quiet-thread', 'Quiet Thread', 0, 'Tie a faint thread of light around an object so you can recognize it by touch.'],
  ['sheltering-glow', 'Sheltering Glow', 1, 'Create a pocket of warm light around a willing companion. Its exact protection is adjudicated by your GM in this demonstration setting.'],
  ['borrowed-dawn', 'Borrowed Dawn', 1, 'Fill a small space with the light and birdsong of a remembered morning.'],
  ['trail-whisper', 'Trail Whisper', 1, 'Ask the wind to repeat the last ordinary sound heard along a nearby path.'],
  ['lantern-bridge', 'Lantern Bridge', 2, 'Describe a bridge of lantern light spanning a modest gap; agree on its limits with your GM.'],
  ['echo-room', 'Echo Room', 2, 'Let companions see an impression of a room as you remember it.'],
  ['keeper-call', 'Keeper’s Call', 1, 'Your lantern briefly shows the direction of a fellow keeper who welcomes the connection.'],
  ['keeper-circle', 'Keeper’s Circle', 2, 'Light a ring of welcoming lamps around your campsite.']
].map(([id,name,level,text]) => ({id,name,level,text,source:'Character Folio original demonstration content'}));
const pack = {
  schemaVersion:1, id:'folio.original-demo', version:'1.0.0', name:'The Lantern Roads', ruleset:'2024', isPrivate:false,
  attribution:'Original demonstration content created for Character Folio. This is homebrew sample data, not an official D&D class or spell collection.',
  coverageNotes:['Levels 1–5; single class; standard array; fixed-average HP.', 'Original demonstration content using the 2024 builder conventions. Spell effects and combat are narrative examples, not a balanced published ruleset.', 'Inventory, equipment purchasing, combat, multiclassing, and cantrip replacement are outside this MVP.'],
  languages:['Dwarvish','Elvish','Giant','Gnomish','Goblin','Halfling','Orc','Draconic','Common Sign Language'],
  species:[
    {id:'roadfolk',name:'Roadfolk',text:'People of the old lantern roads. You can always recall the path of a journey you have walked yourself.',speed:30,hpPerLevel:0,size:'Medium'},
    {id:'mosskin',name:'Mosskin',text:'Small, patient folk whose moss-soft skin carries the scent of rain. Their compact frames are unusually resilient.',speed:25,hpPerLevel:1,size:'Small'}
  ],
  backgrounds:[
    {id:'archive-runner',name:'Archive Runner',text:'You carried fragile records between distant reading rooms. One undelivered letter still waits in your satchel.',abilities:['dex','int','cha'],skills:['History','Investigation'],tool:'Calligrapher’s supplies',originFeatID:'patient-reader',equipment:'A journal, ink, a weatherproof satchel, and a sealed letter. Inventory is a narrative note in this demo.'},
    {id:'night-guide',name:'Night Guide',text:'You guided strangers home by lamplight. You remember faces better than destinations.',abilities:['con','wis','cha'],skills:['Perception','Survival'],tool:'Cartographer’s tools',originFeatID:'weathered',equipment:'A lantern, a worn map, and traveler’s clothes. Inventory is a narrative note in this demo.'}
  ],
  feats:[
    feat('patient-reader','Patient Reader','Your patient study grants proficiency in Arcana.',['origin'][0],{skills:['Arcana']}),
    feat('weathered','Weathered','Your journeys grant 1 additional maximum HP for each character level.','origin',{hpPerLevel:1}),
    feat('ability-improvement','Ability Score Improvement','Increase one ability by 2 or two abilities by 1, to a maximum of 20.','general',{abilityOptions:all,abilityPoints:2}),
    feat('steady-flame','Steady Flame','Increase Constitution or Charisma by 1. Your calm preparation grants proficiency in Insight.','general',{abilityOptions:['con','cha'],abilityPoints:1,skills:['Insight'],abilityMinimums:{cha:13}})
  ],
  spells,
  classes:[{
    id:'lantern-keeper',name:'Lantern Keeper',summary:'Carry a little light into places the world has forgotten.',hitDie:8,primaryAbility:'cha',spellAbility:'cha',saves:['wis','cha'],skillCount:2,
    skillPool:['Arcana','Insight','Medicine','Persuasion','Religion','Survival'],subclassLevel:3,talentLabel:'Practices',
    equipment:'A walking staff and a lantern. This demo records equipment as notes; it does not calculate purchases or armor.',armorFormula:'unarmored',
    features:[feature('lantern','The lantern',1,'Your lantern is a personal keepsake and the focus of your magic.'),feature('roads','Lantern magic',2,'Choose your cantrips and known spells. This example class uses a shared pool of spell slots that refreshes after a rest.'),feature('calling','A calling',3,'Choose which part of the lantern road you will care for.'),feature('two-lights','Two lights',5,'Your story now reaches beyond a single road. Record a place you promise to return to.')],
    talents:[talent('listener','Listener','Learn to notice the words people leave unsaid. Gain proficiency in Insight.',['Insight']),talent('letter-keeper','Letter Keeper','You keep careful records. Gain proficiency in History.',['History']),talent('path-reader','Path Reader','You understand the traces left by travelers. Gain proficiency in Survival.',['Survival']),talent('gentle-hand','Gentle Hand','Your steady care grants proficiency in Medicine.',['Medicine'],2)],
    subclasses:[{id:'waylight',name:'Waylight',text:'You lead the lost toward a place they can call home.',features:[feature('welcome', 'A light in the window',3,'A small lamp becomes your sign of welcome. Describe a place where a friend leaves one burning for you.')],spells:[{level:3,spellIDs:['keeper-call']},{level:5,spellIDs:['keeper-circle']}]}, {id:'memory-keeper',name:'Memory Keeper',text:'You preserve the stories carried by abandoned places.',features:[feature('memory','The remembered road',3,'Keep a short memory of every meaningful place you visit.')],spells:[{level:3,spellIDs:['keeper-call']},{level:5,spellIDs:['keeper-circle']}]}],
    progression:[1,2,3,4,5].map(level=>({level,talents:level<2?1:level<4?2:3,cantrips:level<2?0:level<4?2:3,spells:level<2?0:level<4?2:3,slots:level<2?0:2,slotLevel:level<2?0:level<5?1:2,improvement:level===4})),
    spellIDs:spells.filter(x=>!x.id.startsWith('keeper-')).map(x=>x.id)
  }]
};
writeFileSync(new URL('../Sources/FolioCore/Resources/example-pack.json',import.meta.url), JSON.stringify(pack,null,2)+'\n');
console.log('Built original example pack.');
// Separate fixture keeps every old-format byte/choice contract available for characterization.
const capable = structuredClone(pack);
capable.schemaVersion = 2;
capable.id = 'original.capability-lab'; capable.version = '1.4.0'; capable.name = 'Trail Warden · capability laboratory';
capable.capabilities = {version:1,required:['choices','modifiers','casting','editions','resources','traits','proficiencies','configuration','languages']};
capable.classes = [structuredClone(pack.classes[0])];
const warden = capable.classes[0];
warden.id = 'trail-warden'; warden.name = 'Trail Warden';
const option = (id,name,grants,prerequisite) => ({id,name,text:'Original capability demonstration; not official rules.',grants,...(prerequisite?{prerequisite}:{})});
warden.capabilities = {edition:'2024',configurations:[{id:'guard',name:'Guard stance',text:'A declared conditional stance. No action or resource expenditure is simulated.'}],
  grants:[{id:'focus',kind:'resource',target:'Focus',value:{levelMultiplier:2},recovery:'short rest'},{id:'broad-study',kind:'proficiency',target:'all-skills',rank:'half'}],
  groups:[
    {id:'training',name:'Training',counts:[1,1,2,2,2],replacementLimits:[0,0,1,0,0],options:[option('scholar','Scholar',[{id:'scholar-expertise',kind:'proficiency',target:'Arcana',rank:'expertise'}]),option('runner','Runner',[{id:'runner-speed',kind:'speed',value:{base:10}}]),option('mentor','Mentor',[{id:'mentor-trait',kind:'trait',text:'You train other travelers.'}],{kind:'selection',key:'scholar'})]},
    {id:'style',name:'Style',counts:[1,1,1,1,1],options:[option('guarded','Guarded',[{id:'guard-defense',kind:'armorFormula',value:{base:10,abilities:['con','cha']},condition:{kind:'configuration',key:'guard'}}]),option('calm','Calm',[{id:'calm-skill',kind:'skillAbility',target:'Athletics',ability:'cha'}])]}
  ],
  casting:[{id:'field-book',name:'Field book',mode:'book',ability:'int',spellIDs:warden.spellIDs,counts:[0,2,2,3,3],maximumSpellLevels:[0,1,1,1,2],preparedCounts:[0,1,1,2,2],replacementLimits:[0,0,0,0,0]}]
};
// Mechanism laboratories, not published classes or a claim about every official subclass.
// Their names and prose are original; family keys connect them to registered acceptance.
const familyNames={barbarian:'Stonepulse',bard:'Road Cantor',cleric:'Beacon Votary',druid:'Moss Oracle',fighter:'Bridge Sentinel',monk:'Quiet Step',paladin:'Dawn Promise',ranger:'Boundary Scout',rogue:'Archive Fox',sorcerer:'Ember Heir',warlock:'Night Bargain',wizard:'Margin Scholar',artificer:'Copper Inventor'};
for(const [family,name] of Object.entries(familyNames)) {
  const c=structuredClone(pack.classes[0]); c.id='lab-'+family;c.name=name;
  c.summary='Original '+family+'-family mechanism laboratory; not official class content.';
  c.talents=[];c.features=[];c.subclasses.forEach(s=>{s.features=[];s.spells=[];});
  c.progression.forEach(r=>{r.talents=0;r.spells=0;r.cantrips=0;});
  const martial=['barbarian','fighter','monk','rogue'].includes(family);
  if(martial){c.spellAbility=null;c.progression.forEach(r=>{r.slots=0;r.slotLevel=0;});}
  const id=x=>family+'-'+x;
  const condition={kind:'configuration',key:id('active')};
  const g=(key,kind,extras={})=>({id:id(key),kind,...extras});
  const proficiency=(key,skill,rank='proficient')=>g(key,'proficiency',{target:skill,rank});
  const resource=(key,base=0,levelMultiplier=0)=>g(key,'resource',{target:key,value:{base,levelMultiplier},recovery:'long rest'});
  const trait=(key,text)=>g(key,'trait',{text});
  const choice=(key,grants,prerequisite)=>option(id(key),key,grants,prerequisite);
  const group=(key,options,counts=[1,1,1,1,1])=>({id:id(key),name:key,counts,options,replacementLimits:[0,1,0,1,0]});
  const policy=(mode,spellIDs=['sheltering-glow','borrowed-dawn'],extras={})=>({id:id('casting'),name:name+' casting',mode,ability:'cha',spellIDs,counts:[1,1,1,1,1],maximumSpellLevels:[1,1,1,1,2],replacementLimits:[0,1,1,1,1],...extras});
  const caps={edition:'2024',grants:[],groups:[],configurations:[{id:id('active'),name:'Active declared condition',text:'An original build-time condition, not combat simulation.'}],casting:[]};
  const style=()=>group('style',[choice('guard',[g('guard-defense','armorBonus',{value:{base:1},condition})]),choice('swift',[g('swift-speed','speed',{value:{base:5}})])]);
  if(family==='barbarian') caps.grants=[resource('resolve',2),g('defense','armorFormula',{value:{base:10,abilities:['dex','con']},condition}),g('strength-substitute','skillAbility',{target:'Athletics',ability:'cha',condition}),{...trait('vigorous','Declared vigorous state is active.'),condition}];
  if(family==='bard') caps.grants=[proficiency('expert','Arcana','expertise'),proficiency('broad','all-skills','half'),proficiency('extra','Performance'),resource('inspiration',3)];
  if(family==='cleric'||family==='druid') {
    caps.groups=[group('order',[choice('learned',[proficiency('order-skill','History')]),choice('swift',[g('order-speed','speed',{value:{base:5}})])])];
    caps.grants=[resource('channel',2),g('domain-spell','spell',{target:'keeper-call',level:3})];
    caps.casting=[policy('prepared')];
    if(family==='druid') caps.grants.push({...trait('form','Declared moss form has climbing and small-gap traits.'),condition});
  }
  if(family==='fighter') {caps.groups=[style()];caps.grants=[resource('recovery',2),resource('surge',1)];}
  if(family==='monk') caps.grants=[g('defense','armorFormula',{value:{base:10,abilities:['dex','wis']},condition}),g('movement','speed',{value:{base:10},condition}),resource('focus',0,1),trait('focus-die','The calculated focus die sides follow the level table; attack rolls are not simulated.')];
  if(family==='paladin') {caps.groups=[group('style',[choice('guard',[g('guard-defense','armorBonus',{value:{base:1},condition})]),choice('cantrips',[g('cantrip-one','spell',{target:'little-beacon'}),g('cantrip-two','spell',{target:'paper-bird'})])])];caps.grants=[resource('healing',0,5),resource('channel',1),g('oath','spell',{target:'keeper-call',level:3})];caps.casting=[policy('prepared')];}
  if(family==='ranger'||family==='rogue') {caps.grants=[proficiency('expert','Arcana','expertise'),g('language','language',{target:'Road Cant'})];if(family==='ranger'){caps.groups=[style()];caps.grants.push({...trait('quarry','Configured quarry grants the declared tracking advantage.'),condition});caps.casting=[policy('known')];}}
  if(family==='sorcerer') {caps.groups=[group('metamagic',[choice('distant',[trait('distant','A selected distance-altering spell option.')]),choice('quiet',[trait('quiet','A selected quiet-casting spell option.')])])];caps.grants=[resource('sorcery',0,1),g('durability','hitPoints',{value:{levelMultiplier:1}}),g('scales','armorFormula',{value:{base:13,abilities:['dex']},condition}),{...trait('affinity','Ember affinity resistance is active.'),condition},g('lineage','spell',{target:'keeper-call',level:3})];}
  if(family==='warlock') {caps.groups=[group('invocations',[choice('root',[proficiency('root-training','History')]),choice('dependent',[g('dependent-speed','speed',{value:{base:10}})],{kind:'selection',key:id('root')}),{...choice('repeat',[g('repeat-speed','speed',{value:{base:5}})]),repeatable:true}],[1,2,2,2,2]),group('pact',[choice('tome',[trait('tome','Pact book selected.')]),choice('chain',[trait('chain','Pact companion selected; turns are not simulated.')])])];caps.casting=[policy('known',['sheltering-glow','borrowed-dawn','keeper-call'])];}
  if(family==='wizard'){caps.grants=[proficiency('expert','Arcana','expertise')];caps.casting=[policy('book',['sheltering-glow','borrowed-dawn'],{counts:[1,2,2,2,2],preparedCounts:[1,1,1,1,1],replacementLimits:[0,0,0,0,0]})];}
  if(family==='artificer'){caps.groups=[group('recipes',[choice('foundation',[trait('foundation','Original item recipe learned.')]),choice('advanced',[trait('advanced','Dependent item recipe learned; active applications await I5.')],{kind:'selection',key:id('foundation')})],[1,2,2,2,2])];caps.casting=[policy('prepared')];}
  if(family==='monk') caps.grants.push(g('die-sides','trait',{text:'Focus die sides',value:{table:[4,4,4,4,6]}}));
  if(family==='warlock') caps.grants.push(g('at-will','spell',{target:'little-beacon',spellMode:'atWill',condition}),g('limited-spell','spell',{target:'keeper-circle',spellMode:'limited',level:5}),resource('limited-casts',1));
  if(!martial && !caps.casting.length) caps.casting=[policy('known',family==='bard'?['sheltering-glow','borrowed-dawn','keeper-call']:undefined)];
  c.capabilities=caps;capable.classes.push(c);
}
const olderClass=structuredClone(pack.classes[0]);
olderClass.id='lab-2014-wayfarer';olderClass.name='Old Road Wayfarer';olderClass.capabilities={edition:'2014'};
olderClass.subclasses.forEach(s=>s.capabilities={edition:'2014'});
capable.classes.push(olderClass);
capable.species.push({...structuredClone(pack.species[0]),id:'roadfolk-2014',name:'Old Roadfolk',capabilities:{edition:'2014',grants:[{id:'old-road-common',kind:'language',target:'Common'},{id:'old-road-cant',kind:'language',target:'Road Cant'}]}});
capable.backgrounds.push({...structuredClone(pack.backgrounds[1]),id:'guide-2014',name:'Old Road Guide',abilities:[],originFeatID:'',capabilities:{edition:'2014',groups:[{id:'guide-language',name:'Guide language',languageChoices:true,counts:[1,1,1,1,1],locked:true,options:['Harbor Speech','Trade Sign'].map((name,i)=>option('guide-language-'+i,name,[{id:'guide-language-grant-'+i,kind:'language',target:name}]))}]}});
const summit=structuredClone(pack.classes[0]);
summit.id='summit-warden';summit.name='Summit Warden';summit.summary='Original level-20 martial progression laboratory.';
summit.spellAbility=null;summit.spellIDs=[];summit.talents=[];summit.features=[];
summit.subclasses.forEach(s=>{s.spells=[];s.features=[];});
const summitLevels=[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20];
summit.progression=summitLevels.map(level=>({level,talents:0,cantrips:0,spells:0,slots:0,slotLevel:0,improvement:[4,6,10,14,19].includes(level)}));
summit.capabilities={edition:'2024',grants:[
  {id:'summit-resolve',kind:'resource',target:'Resolve',value:{table:[1,1,2,2,2,3,3,3,4,4,4,5,5,5,6,6,6,7,7,8]},recovery:'long rest'},
  {id:'summit-wisdom-save',kind:'proficiency',target:'save.wis',rank:'proficient',level:14},
  {id:'summit-strength-cap',kind:'abilityCap',target:'str',value:{base:24},level:20},
  {id:'summit-strength',kind:'abilityScore',target:'str',value:{base:4},level:20}
]};
capable.classes.push(summit);
// Common slot arithmetic verified from SRD 5.2.1 p77 / 5.1 p52; original
// acquisition/content below deliberately does not represent a complete Wizard.
const fullSlots=[[2],[3],[4,2],[4,3],[4,3,2],[4,3,3],[4,3,3,1],[4,3,3,2],[4,3,3,3,1],[4,3,3,3,2],[4,3,3,3,2,1],[4,3,3,3,2,1],[4,3,3,3,2,1,1],[4,3,3,3,2,1,1],[4,3,3,3,2,1,1,1],[4,3,3,3,2,1,1,1],[4,3,3,3,2,1,1,1,1],[4,3,3,3,3,1,1,1,1],[4,3,3,3,3,2,1,1,1],[4,3,3,3,3,2,2,1,1]];
const notebook=structuredClone(summit);
notebook.id='notebook-keeper';notebook.name='Notebook Keeper';notebook.summary='Original book and dual-source casting laboratory, not an official class.';
notebook.progression.forEach(row=>row.improvement=false);
notebook.capabilities={edition:'2024',spellPools:[{id:'notebook-slots',name:'Notebook slots',kind:'ordinary',recovery:'long rest',capacities:fullSlots.map(row=>Object.fromEntries(row.map((count,i)=>[i+1,count])))}],casting:[{id:'notebook-study',name:'Notebook study',mode:'book',ability:'int',spellIDs:['sheltering-glow','borrowed-dawn'],counts:summitLevels.map(()=>2),maximumSpellLevels:summitLevels.map(()=>1),preparedCounts:summitLevels.map(()=>1),loadout:'editable',poolIDs:['notebook-slots'],text:'Two learned original spells; choose one current preparation. Higher slots do not grant knowledge.'}]};
notebook.subclasses[0].name='Echo Companion';
notebook.subclasses[0].capabilities={edition:'2024',spellPools:[{id:'echo-charge',name:'Echo charge',kind:'custom',recovery:'short rest',capacities:summitLevels.map(level=>level<3?{}:{1:1})}],casting:[{id:'echo-voice',name:'Echo voice',mode:'limited',ability:'cha',spellIDs:['little-beacon'],counts:summitLevels.map(level=>level<3?0:1),maximumSpellLevels:summitLevels.map(()=>0),poolIDs:['echo-charge'],loadout:'retained'}]};
capable.classes.push(notebook);
notebook.subclasses[0].capabilities.casting[0].legacyClassCasting='preserve';
capable.capabilities.required.push('spell-pools');
capable.feats.find(f=>f.id==='ability-improvement').repeatable=true;
capable.coverageNotes=['Original mechanism fixtures; names do not certify official subclasses.','Summit Warden and Notebook Keeper support explicit levels 1–20. Early laboratories retain their authored 1–5 limits.','Notebook Keeper demonstrates tiered ordinary capacity, a separate custom pool, two casting abilities and editable book preparation. Multiclass and equipment remain pending.'];
writeFileSync(new URL('../Sources/FolioCore/Resources/capability-pack.json',import.meta.url), JSON.stringify(capable,null,2)+'\n');
console.log('Built original schema-2 capability fixture.');
