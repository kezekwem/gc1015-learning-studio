"""Prepare shared interface translations; never copy or print runtime credentials."""
from pathlib import Path
import json,re,os,urllib.request,time,concurrent.futures
SITE=Path(__file__).resolve().parents[1]
raw=Path(os.environ["COURSE_RUNTIME_ENV"]).read_text()
match=re.search(r'^\s*(?:export\s+)?OPENAI_API_KEY\s*=\s*(.*?)\s*$',raw,re.M)
if not match:raise SystemExit("No runtime API key is configured.")
KEY=match[1].strip().strip("\"'")
catalog=json.loads((SITE/"content/translation-catalog.json").read_text())
languages={"zh":"Simplified Chinese (Mandarin)","es":"Spanish","hi":"Hindi"}
def output(p):
 if p.get("status")!="completed":raise ValueError("Translation response was incomplete")
 return ''.join(c.get("text","") for x in p.get("output",[]) for c in x.get("content",[]) if c.get("type")=="output_text")
def work(lang):
 path=SITE/f"content/translations/{lang}.json";values=json.loads(path.read_text()) if path.exists() else {}
 pending=[i for i in catalog["core"] if i not in values];groups=[];group=[];size=0
 for i in pending:
  n=len(catalog["texts"][i])
  if group and size+n>3800:groups.append(group);group=[];size=0
  group.append(i);size+=n
 if group:groups.append(group)
 for j,ids in enumerate(groups):
  source=[catalog["texts"][i] for i in ids]
  segments=[{"id":i,"text":catalog["texts"][i]} for i in ids]
  schema={"type":"object","properties":{"values":{"type":"object","properties":{i:{"type":"string"} for i in ids},"required":ids,"additionalProperties":False}},"required":["values"],"additionalProperties":False}
  body={"model":"gpt-5.6-luna","instructions":"Translate public GC1015 course interface and teaching text into "+languages[lang]+". Preserve meaning, statistical distinctions, ALL ASCII numerals and their EXACT decimal punctuation (do not spell out numerals or introduce a numeral for a number word), all {placeholder} names, units, formula symbols, NYU, GC1015, software identifiers and proper names. Do not solve any exercises or add answers. Keep each item independent and in the supplied order. Plain text only.","input":json.dumps(segments,ensure_ascii=False),"reasoning":{"effort":"low"},"text":{"format":{"type":"json_schema","name":"interface_translation","strict":True,"schema":schema}},"max_output_tokens":12000,"store":False}
  request=urllib.request.Request("https://api.openai.com/v1/responses",data=json.dumps(body).encode(),headers={"Authorization":"Bearer "+KEY,"Content-Type":"application/json"})
  try:
   with urllib.request.urlopen(request,timeout=60) as r:result=json.loads(r.read())
   translated=json.loads(output(result))["values"]
   if len(translated)!=len(ids):raise ValueError("Translation count mismatch")
   for identity,original in zip(ids,source):
    text=translated[identity]
    before=re.findall(r'(?<![A-Za-z])\d+(?:[.,]\d+)*',original);after=re.findall(r'(?<![A-Za-z])\d+(?:[.,]\d+)*',text)
    if sorted(before)!=sorted(after):continue
    values[identity]=text
   path.write_text(json.dumps(values,ensure_ascii=False,indent=2))
   print(json.dumps({"language":lang,"batch":j+1,"batches":len(groups),"translated":len(values),"inputTokens":result.get("usage",{}).get("input_tokens"),"outputTokens":result.get("usage",{}).get("output_tokens")}),flush=True)
  except Exception as e:
   print(json.dumps({"language":lang,"batch":j+1,"failure":type(e).__name__}),flush=True)
 return {"language":lang,"ready":len(values),"core":len(catalog["core"])}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for result in pool.map(work,languages):print(json.dumps(result),flush=True)
