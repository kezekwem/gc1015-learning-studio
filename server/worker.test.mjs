import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import fs from 'node:fs';
import worker from '../dist/server/index.js';
const realFetch=globalThis.fetch;
function environment(options={}){
 const sql=new DatabaseSync(':memory:');
 const DB={prepare(q){return{bind(...args){return{async first(){return sql.prepare(q).get(...args)||null},async run(){return sql.prepare(q).run(...args)}}},async run(){return sql.prepare(q).run()}}}};
 return{OPENAI_API_KEY:'local-test-fixture',DB,ASSETS:{fetch:async()=>new Response('static course file')},...options};
}
const post=(path,data,headers={})=>new Request('https://example.test/api/'+path,{method:'POST',headers:{'Content-Type':'application/json',...headers},body:JSON.stringify(data)});
function provider({kind='revision',sessions=[3],allowed=true,invalid=false,answer='The median is the middle observation.',translation}={}){
 let calls=[];
 globalThis.fetch=async(url,init)=>{
  const b=JSON.parse(init.body);calls.push({url,body:b});
  if(url.endsWith('/moderations'))return Response.json({results:[{flagged:false}]});
  if(url.endsWith('/audio/speech'))return new Response(new Uint8Array([73,68,51,4,0,0]),{headers:{'Content-Type':'audio/mpeg'}});
  const input=JSON.parse(b.input);let value;
  switch(b.text.format.name){
   case 'revision_routing':value={kind,sessions,keywords:'mean median outlier delivery'};break;
   case 'learning_response':value={answer,sourceIds:[input.sourceList[0].id,input.sourceList[0].id,'invented-source']};break;
   case 'learning_support_check':value={allowed,reason:allowed?'none':'assignment'};break;
   case 'course_translation':value={values:Object.fromEntries(input.segments.map(x=>[x.id,translation||x.text]))};break;
   default:throw Error('Unexpected request');
  }
  return Response.json({status:invalid?'incomplete':'completed',output_text:JSON.stringify(value)});
 };
 return calls;
}
test('request validation, origin boundary and static fallback',async()=>{
 const env=environment();
 assert.equal((await worker.fetch(post('chat',{message:''}),env)).status,400);
 assert.equal((await worker.fetch(post('chat',{message:'Hi'},{origin:'https://other.test'}),env)).status,403);
 assert.equal((await worker.fetch(new Request('https://example.test/api/chat',{method:'POST',body:'{broken'}),env)).status,400);
 assert.equal((await worker.fetch(post('chat',[],{}),env)).status,400);
 assert.equal(await(await worker.fetch(new Request('https://example.test/'),env)).text(),'static course file');
 const state=await(await worker.fetch(new Request('https://example.test/api/tutor-status'),env)).json();
 assert.equal(state.coveredThrough,5);assert.equal(state.revisionThrough,4);assert.deepEqual(state.languages,['en','zh','es','hi']);
});
test('missing credentials fail without a provider call',async()=>{
 const calls=provider();assert.equal((await worker.fetch(post('chat',{message:'Explain median'}),environment({OPENAI_API_KEY:undefined}))).status,503);assert.equal(calls.length,0);
});
test('future teaching is blocked before answer generation',async()=>{
 const calls=provider({sessions:[5]});const r=await worker.fetch(post('chat',{message:'Explain session 5 confidence intervals',language:'es'}),environment());const data=await r.json();
 assert.equal(r.status,200);assert.match(data.answer,/01–04/);assert.match(data.answer,/revisión/);assert.equal(calls.length,2);assert.equal(typeof data.speechToken,'string');
});
test('whole-course navigation can refer to Session 05 without teaching it',async()=>{
 const calls=provider({kind:'course',sessions:[5],answer:'Session 05 slides are available in the course resources.'});const r=await worker.fetch(post('chat',{message:'Where are session 5 slides?'}),environment());assert.equal(r.status,200);
 const generation=calls.find(x=>x.body.text?.format.name==='learning_response');const input=JSON.parse(generation.body.input);
 assert(input.sourceList.some(x=>x.url==='/assets/s05/slides.pdf'));assert.equal(input.evidence.length,0);
});
test('citations are deduplicated and cannot invent a source URL',async()=>{
 provider();const r=await worker.fetch(post('chat',{message:'How do mean and median differ?',language:'zh'}),environment());const data=await r.json();
 assert.equal(data.sources.length,1);assert.match(data.sources[0].url,/^\/assets\/s03\//);assert(data.speechToken);assert.equal(data.language,'zh');
});
test('independent checker blocks completion of ungraded assignments',async()=>{
 provider({kind:'assignment',allowed:false,answer:'Filled worksheet: the answer is 42.'});const r=await worker.fetch(post('chat',{message:'Complete my ungraded lab worksheet.'}),environment());const data=await r.json();
 assert.match(data.answer,/including ungraded/);assert(!data.answer.includes('42'));assert(data.speechToken);
});
test('incomplete output fails closed',async()=>{
 provider({invalid:true});assert.equal((await worker.fetch(post('chat',{message:'Explain median'}),environment())).status,502);
});
test('atomic daily budget prevents the next provider call',async()=>{
 const calls=provider();const env=environment({TUTOR_DAILY_CALL_LIMIT:'1'});assert.equal((await worker.fetch(post('chat',{message:'Explain median'}),env)).status,429);assert.equal(calls.length,1);
});
test('unknown translation IDs cannot be used as an arbitrary proxy',async()=>{
 const calls=provider();assert.equal((await worker.fetch(post('translate',{language:'hi',ids:['not-a-course-segment']}),environment())).status,400);assert.equal(calls.length,0);
});
test('translation number changes are rejected before caching',async()=>{
 const catalog=JSON.parse(fs.readFileSync(new URL('../content/translation-catalog.json',import.meta.url)));
 const id=Object.keys(catalog.texts).find(x=>/\b100\b/.test(catalog.texts[x])&&!catalog.core.includes(x));assert(id);
 provider({translation:'Changed to 9999'});const env=environment();const r=await worker.fetch(post('translate',{language:'hi',ids:[id]}),env);assert.equal(r.status,200);const result=await r.json();assert.deepEqual(result.untranslated,[id]);assert.equal(result.values[id],catalog.texts[id]);
 assert.equal(await env.DB.prepare('SELECT value FROM translations WHERE id=? AND language=?').bind(id,'hi').first(),null);
});
test('speech requires an unchanged, signed tutor reply',async()=>{
 const calls=provider();const env=environment();const data=await(await worker.fetch(post('chat',{message:'Explain median'}),env)).json();const before=calls.length;
 assert.equal((await worker.fetch(post('speech',{answer:data.answer+' changed',language:'en',token:data.speechToken}),env)).status,400);assert.equal(calls.length,before);
 const r=await worker.fetch(post('speech',{answer:data.answer,language:'en',token:data.speechToken}),env);assert.equal(r.status,200);assert.equal(r.headers.get('Content-Type'),'audio/mpeg');
 globalThis.fetch=realFetch;
});

test('whole-course accuracy check receives verified MAPS and resource metadata',async()=>{
 const calls=provider({kind:'course',sessions:[],answer:'Explore MAPS through the Career Toolkit.'});
 assert.equal((await worker.fetch(post('chat',{message:'How do I join MAPS?'}),environment())).status,200);
 const check=calls.find(x=>x.body.text?.format.name==='learning_support_check');const input=JSON.parse(check.body.input);
 assert.equal(input.course.mapsCommunity.email,'sps.maps@nyu.edu');assert(input.course.optionalResources.length===15);assert(input.sourceList.some(x=>x.id==='maps'));
});
