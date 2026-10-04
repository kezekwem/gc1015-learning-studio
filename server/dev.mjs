import http from "node:http";
import fs from "node:fs/promises";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {DatabaseSync} from "node:sqlite";
import worker from "../dist/server/index.js";
const base=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"../dist/client");
const sql=new DatabaseSync(":memory:");
const db={prepare(query){return{bind(...args){return{async first(){return sql.prepare(query).get(...args)||null;},async run(){return sql.prepare(query).run(...args);}};},async run(){return sql.prepare(query).run();}};}};
const types={".html":"text/html; charset=utf-8",".css":"text/css",".js":"text/javascript",".json":"application/json",".png":"image/png",".jpg":"image/jpeg",".svg":"image/svg+xml",".pdf":"application/pdf",".mp3":"audio/mpeg",".txt":"text/plain; charset=utf-8",".zip":"application/zip",".xlsx":"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"};
const assets={async fetch(request){
 let name=decodeURIComponent(new URL(request.url).pathname);let target=path.resolve(base,"."+name);
 if(target!==base&&!target.startsWith(base+path.sep))return new Response("Not found",{status:404});
 try{if((await fs.stat(target)).isDirectory())target=path.join(target,"index.html");const b=await fs.readFile(target);return new Response(b,{headers:{"Content-Type":types[path.extname(target)]||"application/octet-stream"}});}catch{return new Response(await fs.readFile(path.join(base,"404.html")),{status:404,headers:{"Content-Type":"text/html"}});}
}};
const env={OPENAI_API_KEY:process.env.OPENAI_API_KEY,OPENAI_MODEL:"gpt-5.6-luna",TUTOR_DAILY_CALL_LIMIT:"600",DB:db,ASSETS:assets};
const server=http.createServer(async(req,res)=>{
 try{
  const chunks=[];for await(const chunk of req)chunks.push(chunk);
  const request=new Request("http://127.0.0.1:8766"+req.url,{method:req.method,headers:req.headers,...(!["GET","HEAD"].includes(req.method)?{body:Buffer.concat(chunks)}:{})});
  const response=await worker.fetch(request,env,{});res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));
 }catch{res.writeHead(500,{"Content-Type":"text/plain"});res.end("The local preview couldn't complete this request.");}
});
server.listen(8766,"127.0.0.1",()=>console.log("GC1015 local preview: http://127.0.0.1:8766/"));
