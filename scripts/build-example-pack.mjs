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
