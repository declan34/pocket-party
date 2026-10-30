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
  progression:object({level:{type:'integer',minimum:1,maximum:5},talents:integer,cantrips:integer,spells:integer,slots:integer,slotLevel:integer,improvement:bool}),
  class:object({id:string,name:string,summary:string,hitDie:{enum:[6,8,10,12]},primaryAbility:ability,spellAbility:{anyOf:[ability,{type:'null'}]},saves:array(ability),skillCount:integer,skillPool:array(string),subclassLevel:integer,talentLabel:string,features:array(ref('feature')),talents:array(ref('talent')),subclasses:array(ref('subclass')),progression:array(ref('progression')),spellIDs:array(string),equipment:string,armorFormula:{enum:['unarmored','vessel-mantle']}},['spellAbility']),
  species:object({...idNameText,speed:integer,hpPerLevel:integer,size:string}),
  background:object({...idNameText,abilities:array(ability),skills:array(string),tool:string,originFeatID:string,equipment:string}),
  feat:object({...idNameText,category:{enum:['origin','general']},minimumLevel:integer,abilityOptions:array(ability),abilityPoints:integer,hpPerLevel:integer,initiativeProficiency:bool,skills:array(string),abilityMinimums:{type:'object',propertyNames:ability,additionalProperties:{type:'integer',minimum:1,maximum:20}}})
};
const schema = {$schema:'https://json-schema.org/draft/2020-12/schema',title:'Character Folio content pack v1',...object({schemaVersion:{const:1},id:string,version:string,name:string,ruleset:{const:'2024'},isPrivate:bool,attribution:string,coverageNotes:array(string),classes:array(ref('class')),species:array(ref('species')),backgrounds:array(ref('background')),feats:array(ref('feat')),spells:array(ref('spell')),languages:array(string)}),$defs:defs};
writeFileSync(new URL('../docs/content-pack.schema.json',import.meta.url),JSON.stringify(schema,null,2)+'\n');
console.log('Wrote content pack JSON Schema');
