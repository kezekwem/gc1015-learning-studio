(function(){
 "use strict";
 var select=document.getElementById("site-language");if(!select)return;
 var language="en";try{language=localStorage.getItem("gc1015-study-language")||"en";}catch(_){}
 if(!["en","zh","es","hi"].includes(language))language="en";
 select.value=language;document.documentElement.lang=language==="zh"?"zh-Hans":language;
 var dictionaries={},dynamic={},busy=false,generation=0,timer,status=document.getElementById("translation-status"),queue=new Map(),blockedUntil=0;
 var labels={en:{loading:"Preparing this section in your study language…",error:"Translation is temporarily unavailable. The English source remains visible."},zh:{loading:"正在准备所选语言的内容……",error:"翻译暂时不可用，英文原文仍然可读。"},es:{loading:"Preparando esta sección en tu idioma…",error:"La traducción no está disponible temporalmente. El original en inglés sigue visible."},hi:{loading:"इस भाग को आपकी अध्ययन भाषा में तैयार किया जा रहा है…",error:"अनुवाद अभी उपलब्ध नहीं है। अंग्रेज़ी मूल पाठ उपलब्ध है।"}};
 function message(kind){if(!status)return;status.hidden=!kind;if(kind)status.textContent=labels[language][kind];}
 function visible(el){var r=el.getBoundingClientRect();return r.bottom>=-80&&r.top<=document.documentElement.clientHeight+600&&r.width>0&&r.height>0;}
 function original(el){return el.dataset.i18nOriginal||el.textContent.trim();}
 function apply(el,id,attribute){
  var value=language==="en"?(attribute?el.getAttribute("data-i18n-original-"+attribute):original(el)):dictionaries[language]?.[id];
  if(value!==undefined){if(attribute)el.setAttribute(attribute,value);else if(el.textContent!==value)el.textContent=value;return true;}return false;
 }
 function markDynamic(root){
  if(!Object.keys(dynamic).length)return;
  var walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),nodes=[],n;
  while(n=walker.nextNode())nodes.push(n);
  nodes.forEach(function(node){var t=node.textContent.trim(),p=node.parentElement;if(!p||!dynamic[t]||p.closest("[data-i18n-id],.chat-thread,.language-picker,script,style,math,svg,code,pre,textarea"))return;var span=document.createElement("span");var raw=node.textContent,prefix=raw.slice(0,raw.length-raw.trimStart().length),suffix=raw.slice(raw.trimEnd().length);span.dataset.i18nId=dynamic[t];span.dataset.i18nOriginal=t;span.textContent=t;node.replaceWith(span);if(prefix)span.before(document.createTextNode(prefix));if(suffix)span.after(document.createTextNode(suffix));});
 }
 function scan(){
  markDynamic(document.body);
  document.querySelectorAll("[data-i18n-id]").forEach(function(el){var id=el.dataset.i18nId;if(!apply(el,id)&&visible(el))queue.set(id,el);});
  ["aria-label","placeholder","alt"].forEach(function(attr){document.querySelectorAll("[data-i18n-"+attr+"]").forEach(function(el){var id=el.getAttribute("data-i18n-"+attr);if(!apply(el,id,attr)&&visible(el))queue.set(id,el);});});
  if(language==="en"){queue.clear();message();return;}
  pump();
 }
 async function pump(){
  if(busy||!queue.size||language==="en"||Date.now()<blockedUntil)return;
  var ids=[],size=0;for(var entry of queue){var count=original(entry[1]).length;if(ids.length&&size+count>4500)break;ids.push(entry[0]);size+=count;if(ids.length===30)break;}
  if(!ids.length)return;
  var selected=language,stamp=generation;busy=true;message("loading");ids.forEach(function(id){queue.delete(id);});
  try{
   var response=await fetch("/api/translate",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({language:selected,ids:ids})});
   var result=await response.json();if(!response.ok||!result.values)throw new Error("Translation unavailable");
   dictionaries[selected]=Object.assign(dictionaries[selected]||{},result.values);
   if(stamp===generation){message(result.untranslated?.length?"error":undefined);scan();}
  }catch(_){if(stamp===generation){message("error");blockedUntil=Date.now()+60000;}queue.clear();}
  finally{busy=false;if(queue.size)setTimeout(pump,100);}
 }
 async function load(){
  var selected=language;
  if(selected!=="en"&&!dictionaries[selected])try{var r=await fetch("/assets/i18n-"+selected+".json");dictionaries[selected]=r.ok?await r.json():{};}catch(_){dictionaries[selected]={};}
  if(selected===language){scan();window.dispatchEvent(new CustomEvent("course-translations-ready"));}
 }
 window.CourseLanguage={text:function(source){return language==="en"?source:(dictionaries[language]?.[dynamic[source]]||source);},get:function(){return language;},refresh:function(){clearTimeout(timer);timer=setTimeout(scan,60);}};
 select.addEventListener("change",function(){language=select.value;generation++;blockedUntil=0;queue.clear();document.documentElement.lang=language==="zh"?"zh-Hans":language;try{localStorage.setItem("gc1015-study-language",language);}catch(_){}message();window.dispatchEvent(new CustomEvent("course-language-change",{detail:{language:language}}));load();});
 fetch("/assets/dynamic-texts.json").then(function(r){return r.json();}).then(function(x){dynamic=x;scan();window.dispatchEvent(new CustomEvent("course-translations-ready"));}).catch(function(){});
 new MutationObserver(function(mutations){if(mutations.some(function(m){return !m.target.closest?.("[data-i18n-id],#translation-status,.chat-thread");})){clearTimeout(timer);timer=setTimeout(scan,80);}}).observe(document.body,{childList:true,subtree:true});
 window.addEventListener("scroll",function(){clearTimeout(timer);timer=setTimeout(scan,180);},{passive:true});
 var mc=document.modelContext;if(mc?.registerTool){var lifecycle=new AbortController();mc.registerTool({name:"set_course_study_language",title:"Set course study language",description:"Choose the reading and tutor language. Translates only published public course text through the same dropdown behavior. User-entered chat is not automatically translated.",inputSchema:{type:"object",properties:{language:{type:"string",enum:["en","zh","es","hi"]}},required:["language"],additionalProperties:false},annotations:{readOnlyHint:false},execute:function(x){if(!["en","zh","es","hi"].includes(x.language))throw new Error("Unsupported study language.");select.value=x.language;select.dispatchEvent(new Event("change"));return {language:language,originalFiles:"English"};}},{signal:lifecycle.signal});window.addEventListener("pagehide",function(){lifecycle.abort();},{once:true});}
 load();
}());
