import { writeFileSync } from 'node:fs';
const string = {type:'string'};
const integer = {type:'integer'};
const bool = {type:'boolean'};
const ability = {enum:['str','dex','con','int','wis','cha']};
const array = items => ({type:'array',items});
const ref = name => ({$ref:`#/$defs/${name}`});
const object = (properties, optional=[]) => ({type:'object',additionalProperties:false,required:Object.keys(properties).filter(k=>!optional.includes(k)),properties});
const idNameText = {id:string,name:string,text:string};
const defs = {
  feature:object({...idNameText,level:integer}),
  talent:object({...idNameText,minimumLevel:integer,exclusiveGroup:string,skills:array(string),requires:array(string)}),
  spell:object({...idNameText,level:integer,source:string,unavailableReason:{type:['string','null']}},['unavailableReason']),
  grant:object({level:integer,spellIDs:array(string)}),
  subclass:object({...idNameText,features:array(ref('feature')),spells:array(ref('grant'))}),
  progression:object({level:{type:'integer',minimum:1,maximum:20},talents:integer,cantrips:integer,spells:integer,slots:integer,slotLevel:integer,improvement:bool}),
  class:object({id:string,name:string,summary:string,hitDie:{enum:[6,8,10,12]},primaryAbility:ability,spellAbility:{anyOf:[ability,{type:'null'}]},saves:array(ability),skillCount:integer,skillPool:array(string),subclassLevel:integer,talentLabel:string,features:array(ref('feature')),talents:array(ref('talent')),subclasses:array(ref('subclass')),progression:array(ref('progression')),spellIDs:array(string),equipment:string,armorFormula:{enum:['unarmored','vessel-mantle']}},['spellAbility']),
  species:object({...idNameText,speed:integer,hpPerLevel:integer,size:string}),
  background:object({...idNameText,abilities:array(ability),skills:array(string),tool:string,originFeatID:string,equipment:string}),
  feat:object({...idNameText,category:{enum:['origin','general']},minimumLevel:integer,abilityOptions:array(ability),abilityPoints:integer,hpPerLevel:integer,initiativeProficiency:bool,skills:array(string),abilityMinimums:{type:'object',propertyNames:ability,additionalProperties:{type:'integer',minimum:1,maximum:20}}})
};
const optionalObject = properties => object(properties, Object.keys(properties));
defs.ruleValue = optionalObject({base:integer,abilities:array(ability),levelMultiplier:integer,proficiencyMultiplier:integer,table:array(integer),minimum:integer});
defs.predicate = object({kind:{enum:['all','any','not','level','ability','selection','proficiency','configuration','subclass']},key:string,minimum:integer,children:array(ref('predicate'))},['key','minimum','children']);
defs.capabilityGrant = object({id:string,kind:{enum:['proficiency','skillAbility','skillBonus','armorFormula','armorBonus','hitPoints','initiative','speed','speedBase','abilityScore','trait','resource','spell','unsupported','manual']},target:string,value:ref('ruleValue'),rank:{enum:['none','half','proficient','expertise']},ability,condition:ref('predicate'),level:integer,text:string,recovery:string},['target','value','rank','ability','condition','level','text','recovery']);
defs.option = object({...idNameText,prerequisite:ref('predicate'),grants:array(ref('capabilityGrant')),repeatable:bool,exclusiveGroup:string},['prerequisite','repeatable','exclusiveGroup']);
defs.group = object({id:string,name:string,counts:array(integer),options:array(ref('option')),replacementLimits:array(integer),condition:ref('predicate'),locked:bool},['replacementLimits','condition','locked']);
defs.group.properties.requiredOptionID = string;
defs.group.properties.languageChoices = bool;
defs.group.properties.requiredOptionIDs = array(string);
defs.group.properties.waiveRequiredFamilyIfOwned = bool;
defs.group.properties.requirementTiming = {enum:['ongoing','acquisition']};
defs.group.properties.exclusiveGroupExceptions = array(string);
defs.capabilityGrant.properties.kind.enum.push('size','language','abilityCap');
defs.feat.properties.repeatable = bool;
defs.capabilityGrant.properties.spellMode = {enum:['granted','prepared','atWill','limited','ritual']};
defs.configuration = object({...idNameText,prerequisite:ref('predicate'),exclusiveGroup:string},['prerequisite','exclusiveGroup']);
defs.casting = object({id:string,name:string,mode:{enum:['known','prepared','book','granted','ritual','limited','atWill']},ability,spellIDs:array(string),counts:array(integer),maximumSpellLevels:array(integer),replacementLimits:array(integer),preparedCounts:array(integer),condition:ref('predicate'),text:string},['replacementLimits','preparedCounts','condition','text']);
Object.assign(defs.casting.properties,{loadout:{enum:['editable','retained']},poolIDs:array(string),preparation:ref('ruleValue'),alwaysGrantedSpellIDs:array(string),legacyClassCasting:{enum:['preserve','replace']}});
defs.spellPool=object({id:{type:'string',minLength:1,maxLength:120},name:{type:'string',minLength:1,maxLength:200},kind:{enum:['ordinary','pact','limited','custom']},recovery:{type:'string',minLength:1,maxLength:200},capacities:{type:'array',minItems:1,maxItems:20,items:{type:'object',propertyNames:{pattern:'^[1-9]$'},additionalProperties:{type:'integer',minimum:0,maximum:100},maxProperties:9}},condition:ref('predicate')},['condition']);
defs.adapter = object({edition:{enum:['2014','2024']},canonicalID:string,label:string,replacementGrants:array(ref('capabilityGrant')),subclassLevel:integer},['subclassLevel']);
defs.definitionCapabilities = object({edition:{enum:['2014','2024']},grants:array(ref('capabilityGrant')),groups:array(ref('group')),configurations:array(ref('configuration')),casting:array(ref('casting')),adapters:array(ref('adapter'))},['grants','groups','configurations','casting','adapters']);
defs.definitionCapabilities.properties.spellPools={type:'array',maxItems:32,items:ref('spellPool')};
defs.packCapabilities = object({version:{const:1},required:array({enum:['choices','modifiers','casting','editions','resources','traits','proficiencies','configuration','languages']})});
defs.packCapabilities.properties.required.items.enum.push('spell-pools');
defs.packCapabilities.properties.required.items.enum.push('multiclass');
defs.casterContribution=object({kind:{enum:['ordinary','independent','none']},divisor:{type:'integer',minimum:1,maximum:20},rounding:{enum:['down','up']},startsAt:{type:'integer',minimum:1,maximum:20},poolIDs:array(string),reciprocalSlotUse:bool});
defs.multiclass=object({canonicalID:{type:'string',minLength:1,maxLength:120},prerequisites:ref('predicate'),startingProficiencies:array(ref('capabilityGrant')),laterProficiencies:array(ref('capabilityGrant')),casting:ref('casterContribution')},['prerequisites','startingProficiencies','casting']);
defs.class.properties.multiclass=ref('multiclass');
defs.multiclass.properties.laterSkillCount={type:'integer',minimum:0,maximum:4};
defs.feature.properties.canonicalID={type:'string',minLength:1,maxLength:120};
for (const name of ['class','subclass','species','background','feat']) defs[name].properties.capabilities = ref('definitionCapabilities');
const schema = {$schema:'https://json-schema.org/draft/2020-12/schema',title:'Pocket Party content pack v1/v2',...object({schemaVersion:{enum:[1,2]},capabilities:ref('packCapabilities'),id:string,version:string,name:string,ruleset:{enum:['2014','2024']},isPrivate:bool,attribution:string,coverageNotes:array(string),classes:array(ref('class')),species:array(ref('species')),backgrounds:array(ref('background')),feats:array(ref('feat')),spells:array(ref('spell')),languages:array(string)},['capabilities']),allOf:[{if:{properties:{schemaVersion:{const:1}}},then:{properties:{ruleset:{const:'2024'}}}},{if:{properties:{schemaVersion:{const:2}}},then:{required:['capabilities']}}],$defs:defs};
// The shared definitions permit v2 high levels; v1 keeps its existing boundary.
schema.allOf[0].then.properties.classes={type:'array',items:{properties:{progression:{type:'array',items:{properties:{level:{maximum:5}}}},subclassLevel:{minimum:1,maximum:5}}}};
schema.allOf[0].then.properties.feats={type:'array',items:{properties:{minimumLevel:{minimum:1,maximum:5}}}};
defs.feat.properties.minimumLevel={type:'integer',minimum:1,maximum:20};
for(const [definition,key] of [[defs.ruleValue,'table'],[defs.group,'counts'],[defs.group,'replacementLimits'],[defs.casting,'counts'],[defs.casting,'maximumSpellLevels'],[defs.casting,'replacementLimits'],[defs.casting,'preparedCounts']]) definition.properties[key].maxItems=20;
const boundedID={type:'string',minLength:1,maxLength:120};
const boundedInt=(minimum,maximum)=>({type:'integer',minimum,maximum});
const itemKinds=['armor','shield','weapon','ammunition','gear'];
defs.itemModifier=object({id:boundedID,kind:{enum:['armor','attack','damage','speed']},amount:boundedInt(-20,20)});
defs.equipmentRule=object({kind:{enum:['unarmed','weaponAbility','attackBonus','damageBonus','attunementLimit','attunementEligibility','masteryLimit','applicationLimit','recipe']},ability,damageType:boundedID,training:boundedID,itemKind:{enum:itemKinds},modifiers:{type:'array',maxItems:16,items:ref('itemModifier')}},['ability','damageType','training','itemKind','modifiers']);
defs.item=object({id:boundedID,name:boundedID,edition:{enum:['2014','2024']},kind:{enum:itemKinds},weight:{type:'number',minimum:0,maximum:10000},cost:boundedInt(0,100000000),canonicalID:boundedID,training:boundedID,properties:{type:'array',uniqueItems:true,items:{enum:['finesse','versatile','twoHanded','heavy','ranged','ammunition','light','thrown']}},armorBase:boundedInt(0,30),dexterityCap:boundedInt(0,10),strengthMinimum:boundedInt(1,30),stealthDisadvantage:bool,damageDice:boundedInt(1,10),damageSides:{enum:[4,6,8,10,12]},versatileSides:{enum:[4,6,8,10,12]},damageType:boundedID,mastery:boundedID,attunement:bool,attunementTraining:boundedID,modifiers:{type:'array',maxItems:16,items:ref('itemModifier')},support:{enum:['supported','manual','unsupported']},text:{type:'string',maxLength:20000}},['canonicalID','training','properties','armorBase','dexterityCap','strengthMinimum','stealthDisadvantage','damageDice','damageSides','versatileSides','damageType','mastery','attunement','attunementTraining','modifiers','support','text']);
defs.equipmentChoice=object({id:boundedID,name:boundedID,options:{type:'array',minItems:1,maxItems:100,items:object({id:boundedID,name:boundedID,items:{type:'object',maxProperties:100,propertyNames:boundedID,additionalProperties:boundedInt(1,1000)},gold:boundedInt(0,100000)})}});
defs.class.properties.startingEquipment={type:'array',maxItems:100,items:ref('equipmentChoice')};
defs.background.properties.startingEquipment={type:'array',maxItems:100,items:ref('equipmentChoice')};
defs.capabilityGrant.properties.kind.enum.push('equipment');
defs.capabilityGrant.properties.equipment=ref('equipmentRule');
defs.equipmentRule.properties.requiresBinding=bool;
defs.predicate.properties.kind.enum.push('equipment');
defs.packCapabilities.properties.required.items.enum.push('equipment');
schema.properties.items={type:'array',maxItems:2000,items:ref('item')};
schema.allOf.push({if:{required:['items']},then:{properties:{schemaVersion:{const:2},capabilities:{properties:{required:{contains:{const:'equipment'}}}}}}});
writeFileSync(new URL('../docs/content-pack.schema.json',import.meta.url),JSON.stringify(schema,null,2)+'\n');
console.log('Wrote content pack JSON Schema');
