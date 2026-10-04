"""Compile revision evidence, public translation segments, and the Worker."""
from pathlib import Path
from bs4 import BeautifulSoup, NavigableString
from pypdf import PdfReader
import json, hashlib, re
SITE=Path(__file__).resolve().parents[1]
CLIENT=SITE/"dist/client"
DATA=json.loads((SITE/"content/course.json").read_text())
TEXTS={};EVIDENCE=[];CORE=set();DYNAMIC={}
def key(text):
 text=text.strip()
 identity=hashlib.sha256(text.encode()).hexdigest()[:16]
 assert identity not in TEXTS or TEXTS[identity]==text
 TEXTS[identity]=text
 return identity
def strings(obj):
 if isinstance(obj,str):yield obj
 elif isinstance(obj,(list,tuple)):
  for item in obj:yield from strings(item)
 elif isinstance(obj,dict):
  for item in obj.values():yield from strings(item)
for text in strings(DATA):
 if len(text)>1:
  identity=key(text);CORE.add(identity);DYNAMIC[text]=identity
# Visible dynamic interface labels and feedback (numbers/formulas are preserved).
labels=["Mean","Median","Sample SD","Standard error","Margin of error","This run covers","Observed late rate","All-case lower bound","All-case upper bound","P(event | positive)","Sensitivity","Large expected profit","Flexible expected profit","Display","Histogram bin width","Individual observations · dot plot","Distribution · histogram","10 minutes","20 minutes","Last delivery time:","Selection bias in sample mean:","Probability of rain:","Underlying event rate:","Independent observations per sample","Confidence level","Download these five values · CSV","Draw another 100 samples","Pause & predict","Choose a prediction, then check its explanation.","All three checks & evidence stamp →","One long delivery. Two different summaries.","Which summary follows the tail?","Can a narrow interval still be wrong?","Conditional risk needs a reference group","Confidence is a property of the procedure","Screen outcomes among 1,000 products","Actual condition","Positive screen","Negative screen","Event","No event","Question","Measures","Distribution","Risk","Uncertainty","Knowledge checks","Correct","Not yet","Build the question","Your decision question","Stakeholder","Decision","Population","Measure","Period","The denominator changes the story","The ingredient list for a useful question","Complete all five ingredients to build the question.","Claim this evidence stamp","Evidence stamp earned","Explore the experiment and answer all three checks correctly.","Explore the experiment first.","All three checks must be correct before claiming this stamp."]
for text in labels:
 identity=key(text);CORE.add(identity);DYNAMIC[text]=identity
# Include readable JavaScript literals, with both quote forms tokenized together.
UI_IDS=set()
ui=(CLIENT/"assets/studio.js").read_text()
def js_literals(source):
 i=0
 while i<len(source):
  ch=source[i]
  if ch in ["'",'"']:
   quote=ch;j=i+1;parts=[]
   while j<len(source):
    if source[j]=="\\" and j+1<len(source):parts.extend(source[j:j+2]);j+=2;continue
    if source[j]==quote:break
    parts.append(source[j]);j+=1
   yield ''.join(parts).replace("\\'","'").replace('\\"','"').replace('\\n','\n')
   i=j+1;continue
  if source[i:i+2]=='//':
   end=source.find('\n',i);i=len(source) if end<0 else end+1;continue
  if source[i:i+2]=='/*':
   end=source.find('*/',i+2);i=len(source) if end<0 else end+2;continue
  previous=source[:i].rstrip()[-1:] if i else ''
  if ch=='/' and previous in ['(', '=', ',', ':', '!', '[', '{', '?', ';', '|', '&']:
   j=i+1;in_class=False
   while j<len(source):
    if source[j]=='\\':j+=2;continue
    if source[j]=='[':in_class=True
    elif source[j]==']':in_class=False
    elif source[j]=='/' and not in_class:break
    j+=1
   i=j+1;continue
  i+=1
for text in js_literals(ui):
 if '<' in text:
  part=BeautifulSoup(text,'html.parser')
  candidates=[str(n).strip() for n in part.descendants if isinstance(n,NavigableString)]
 else:candidates=[text.strip()]
 for item in candidates:
  if len(item)<3 or not re.search(r'[A-Za-z]{3}',item) or not (' ' in item or item in ['Event','Mean','Median','Sensitivity','Display']):continue
  if item.startswith(('#','.', '[','/','http')) or re.search(r'data-|aria-|class=|style=|stroke|fill=|target=|rel=|function\(|Object\.|additionalProperties|dataset|font-family',item):continue
  identity=key(item);CORE.add(identity);DYNAMIC[item]=identity;UI_IDS.add(identity)

assert "Five fictional delivery times: 18, 20, 22, 24, and a value you control. All values are minutes." in DYNAMIC
# Build evidence before adding translation wrappers. Cite only existing anchors.
for session in DATA["sessions"][:-1]:
 i=session["id"];folder=CLIENT/f"assets/s{i:02}"
 for kind,name in [("toolkit","toolkit.html"),("lab","lab.html")]:
  soup=BeautifulSoup((folder/name).read_text(),"html.parser")
  for tag in soup.select("script,style,.outline,.studio-reader-nav"):tag.decompose()
  cards=soup.select(".blk,.card")
  if not cards:cards=[soup.find("main") or soup.body]
  for j,card in enumerate(cards):
   text=card.get_text(" ",strip=True)
   if len(text)<60:continue
   heading=card.find(["h2","h3","h4"]) or card.select_one(".hd")
   title=heading.get_text(" ",strip=True) if heading else session["topic"]
   anchor=card.get("id")
   if not anchor:
    previous=card.find_previous(attrs={"id":True});anchor=previous.get("id") if previous else None
   words=text.split()
   for k in range(0,len(words),420):
    EVIDENCE.append({"id":f"s{i}-{kind}-{j}-{k//420}","session":i,"kind":kind,"title":f"Session {i:02} · {title} · "+("Study toolkit" if kind=="toolkit" else "Laboratory guide"),"url":f"/assets/s{i:02}/{name}"+("#"+anchor if anchor else ""),"text":" ".join(words[k:k+420])})
 slide_text=json.loads((SITE/"content/slide-text.json").read_text()).get(str(i),[]) if (SITE/"content/slide-text.json").exists() else []
 for j,p in enumerate(PdfReader(folder/"slides.pdf").pages):
  text=(slide_text[j] if j<len(slide_text) else (p.extract_text() or "")).strip()
  if len(text)>70:EVIDENCE.append({"id":f"s{i}-slide-{j+1}","session":i,"kind":"slides","title":f"Session {i:02} · slide {j+1}","url":f"/assets/s{i:02}/slides.pdf#page={j+1}","text":text[:3200]})
# Wrap readable HTML text, preserving mathematical markup, code, input and semantics.
skip={"script","style","math","svg","pre","code","textarea","title","noscript","audio"}
for path in CLIENT.rglob("*.html"):
 soup=BeautifulSoup(path.read_text(),"html.parser")
 for wrapper in soup.select("span[data-i18n-id]"):wrapper.unwrap()
 for node in list(soup.body.descendants if soup.body else []):
  if not isinstance(node,NavigableString):continue
  text=str(node);clean=text.strip()
  if len(clean)<2 or not re.search(r"[A-Za-z]",clean):continue
  if any(p.name in skip or "language-picker" in p.get("class",[]) or "chat-thread" in p.get("class",[]) or "monogram" in p.get("class",[]) for p in node.parents):continue
  identity=key(clean)
  if "/assets/" not in str(path) and "/measurement-atlas/" not in str(path):CORE.add(identity)
  if node.parent.name=="option":
   node.parent["data-i18n-id"]=identity;node.parent["data-i18n-original"]=clean
  else:
   span=soup.new_tag("span",attrs={"data-i18n-id":identity,"data-i18n-original":clean})
   span.string=clean
   prefix=text[:len(text)-len(text.lstrip())];suffix=text[len(text.rstrip()):]
   node.replace_with(span)
   if prefix:span.insert_before(NavigableString(prefix))
   if suffix:span.insert_after(NavigableString(suffix))
 for tag in soup.select("[aria-label],[placeholder],[alt]"):
  for attr in ["aria-label","placeholder","alt"]:
   if tag.get(attr) and re.search(r"[A-Za-z]",tag[attr]):
    identity=key(tag[attr]);tag["data-i18n-"+attr]=identity;tag["data-i18n-original-"+attr]=tag[attr]
    if "/assets/" not in str(path):CORE.add(identity)
 if not soup.find("script",src="/assets/i18n.js"):
  t=soup.new_tag("script",src="/assets/i18n.js",defer=True);soup.body.append(t)
 if not soup.find(id="site-language"):
  nav=soup.select_one(".studio-reader-nav") or soup.find("header") or soup.body
  picker=BeautifulSoup('<label class="language-picker"><span>Language</span><select id="site-language" aria-label="Study language"><option value="en">English</option><option value="zh">中文（普通话）</option><option value="es">Español</option><option value="hi">हिन्दी</option></select></label>',"html.parser")
  nav.append(picker)
  if not soup.find("link",href="/assets/language.css"):
   t=soup.new_tag("link",rel="stylesheet",href="/assets/language.css");soup.head.append(t)
 if not soup.find(id="translation-status"):
  t=soup.new_tag("div",id="translation-status",attrs={"class":"translation-status","role":"status","hidden":True});soup.body.append(t)
 path.write_text(str(soup))
translations={}
for lang in ["zh","es","hi"]:
 path=SITE/f"content/translations/{lang}.json"
 translations[lang]=json.loads(path.read_text()) if path.exists() else {}
 (CLIENT/f"assets/i18n-{lang}.json").write_text(json.dumps(translations[lang],ensure_ascii=False))
(CLIENT/"assets/dynamic-texts.json").write_text(json.dumps(DYNAMIC,ensure_ascii=False))
(SITE/"content/translation-catalog.json").write_text(json.dumps({"texts":TEXTS,"core":sorted(CORE),"ui":sorted(UI_IDS)},ensure_ascii=False,indent=2))
career=json.loads((SITE/"content/career-resources.json").read_text())
maps=json.loads((SITE/"content/maps-community.json").read_text())
compiled="const MAPS="+json.dumps(maps,ensure_ascii=False)+";\nconst CAREER="+json.dumps(career,ensure_ascii=False)+";\nconst DATA="+json.dumps(DATA,ensure_ascii=False)+";\nconst EVIDENCE="+json.dumps(EVIDENCE,ensure_ascii=False)+";\nconst TEXTS="+json.dumps(TEXTS,ensure_ascii=False)+";\nconst TRANSLATIONS="+json.dumps(translations,ensure_ascii=False)+";\n"
worker=SITE/"dist/server";worker.mkdir(exist_ok=True)
(worker/"index.js").write_text(compiled+(SITE/"server/worker.js").read_text())
(SITE/"dist/.openai").mkdir(exist_ok=True)
(SITE/"dist/.openai/hosting.json").write_text((SITE/".openai/hosting.json").read_text())
print(json.dumps({"revisionThrough":max(s["id"] for s in DATA["sessions"])-1,"evidenceChunks":len(EVIDENCE),"translationSegments":len(TEXTS),"coreSegments":len(CORE),"workerBytes":(worker/"index.js").stat().st_size}))
