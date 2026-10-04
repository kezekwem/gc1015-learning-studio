(function(){
 "use strict";
 var form=document.getElementById("chat-form");if(!form)return;
 var input=document.getElementById("chat-message"),thread=document.getElementById("chat-thread"),send=document.getElementById("send-question"),clear=document.getElementById("clear-chat"),status=document.getElementById("chat-status"),history=[],pending=false,audioUrls=[];
 var labels={
 en:{user:"You",bot:"AI Study Tutor",busy:"Checking the course sources…",error:"The tutor couldn't respond. Your question is still in the box; please try again.",listen:"Listen to this reply · AI voice",audio:"Preparing audio…",audioError:"Audio is unavailable just now. Please try again.",sources:"Explore the sources",send:"Ask the study tutor →",newChat:"New conversation",placeholder:"Describe the concept, or share the step you already tried…"},
 zh:{user:"你",bot:"AI学习辅导",busy:"正在核对课程资料……",error:"辅导暂时无法回复。你的问题仍在输入框中，请重试。",listen:"收听此回复 · AI语音",audio:"正在准备语音……",audioError:"语音暂时不可用，请稍后重试。",sources:"查看相关资料",send:"向学习辅导提问 →",newChat:"新对话",placeholder:"描述概念，或告诉我你已经尝试的步骤……"},
 es:{user:"Tú",bot:"Tutor de estudio con IA",busy:"Consultando los materiales del curso…",error:"El tutor no pudo responder. Tu pregunta sigue en el cuadro; vuelve a intentarlo.",listen:"Escuchar esta respuesta · voz de IA",audio:"Preparando audio…",audioError:"El audio no está disponible ahora. Inténtalo de nuevo.",sources:"Explorar las fuentes",send:"Preguntar al tutor →",newChat:"Nueva conversación",placeholder:"Describe el concepto o el paso que ya intentaste…"},
 hi:{user:"आप",bot:"AI अध्ययन सहायक",busy:"पाठ्यक्रम के स्रोत देख रहा हूँ…",error:"सहायक अभी उत्तर नहीं दे पाया। आपका प्रश्न बॉक्स में है; फिर कोशिश करें।",listen:"यह उत्तर सुनें · AI आवाज़",audio:"ऑडियो तैयार हो रहा है…",audioError:"ऑडियो अभी उपलब्ध नहीं है। फिर कोशिश करें।",sources:"स्रोत देखें",send:"अध्ययन सहायक से पूछें →",newChat:"नई बातचीत",placeholder:"अवधारणा या आपके द्वारा आज़माया गया कदम बताइए…"}
 };
 function lang(){return window.CourseLanguage?.get()||"en";}
 function ui(){var language=lang(),t=labels[language];send.textContent=t.send;clear.textContent=t.newChat;input.placeholder=t.placeholder;
 var welcome=thread.querySelector(".chat-welcome");if(welcome){var texts={en:["A good question is a good start.","Ask about an idea, a chart, or where to find a resource. Share what you have already tried when you need help with a task."],zh:["好的问题，是学习的起点。","你可以询问概念、图表或资源的位置。需要任务指导时，请说明你已经尝试了什么。"],es:["Una buena pregunta es un buen comienzo.","Pregunta sobre una idea, un gráfico o dónde encontrar un recurso. Si necesitas orientación para una actividad, comparte lo que ya intentaste."],hi:["अच्छा सवाल सीखने की अच्छी शुरुआत है।","किसी विचार, चार्ट या संसाधन के बारे में पूछें। किसी कार्य में मदद चाहिए तो बताइए कि आपने पहले क्या प्रयास किया है।"]}[language];welcome.querySelector("h2,h3").textContent=texts[0];welcome.querySelector("p").textContent=texts[1];}
 }
 function message(role,text,language){
  thread.querySelector(".chat-welcome")?.remove();
  var box=document.createElement("article");box.className="chat-message "+role;box.lang=language==="zh"?"zh-Hans":language;
  var who=document.createElement("div");who.className="speaker";who.textContent=labels[language][role==="user"?"user":"bot"]+" · "+({en:"English",zh:"中文",es:"Español",hi:"हिन्दी"}[language]);box.append(who);
  var body=document.createElement("p");body.textContent=text;box.append(body);thread.append(box);thread.scrollTop=thread.scrollHeight;return box;
 }
 async function ask(question){
  if(pending||!question.trim())return;
  var language=lang();pending=true;send.disabled=true;clear.disabled=true;form.setAttribute("aria-busy","true");status.textContent=labels[language].busy;
  var userBox=message("user",question,language);
  try{
   var r=await fetch("/api/chat",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({message:question,language:language,history:history.slice(-6)})}),data=await r.json();
   if(!r.ok||typeof data.answer!=="string")throw new Error(data.error||labels[language].error);
   history.push({role:"user",content:question},{role:"assistant",content:data.answer});history=history.slice(-8);
   var box=message("assistant",data.answer,language);
   if(data.sources?.length){var sources=document.createElement("div");sources.className="chat-sources";var heading=document.createElement("strong");heading.textContent=labels[language].sources;sources.append(heading);data.sources.forEach(function(s){if(typeof s.url!=="string"||!s.url.startsWith("/")||s.url.startsWith("//"))return;var a=document.createElement("a");a.href=s.url;a.target="_blank";a.rel="noopener";a.textContent=s.title+" ↗";sources.append(a);});box.append(sources);}
   if(data.speechToken){var b=document.createElement("button");b.type="button";b.className="secondary";b.textContent=labels[language].listen;b.addEventListener("click",async function(){b.disabled=true;b.textContent=labels[language].audio;try{var response=await fetch("/api/speech",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({answer:data.answer,language:language,token:data.speechToken})});if(!response.ok)throw new Error("Audio unavailable");var url=URL.createObjectURL(await response.blob());audioUrls.push(url);var audio=document.createElement("audio");audio.controls=true;audio.src=url;audio.setAttribute("aria-label",labels[language].listen);box.append(audio);b.hidden=true;audio.play().catch(function(){});}catch(_){b.disabled=false;b.textContent=labels[language].audioError;}});box.append(b);}
   input.value="";status.textContent="";thread.scrollTop=thread.scrollHeight;return {answer:data.answer,sources:data.sources,language:language,revisionThrough:data.revisionMax};
  }catch(e){userBox.remove();status.textContent=e.message===labels[language].error?e.message:labels[language].error;throw e;}
  finally{pending=false;send.disabled=false;clear.disabled=false;form.removeAttribute("aria-busy");}
 }
 form.addEventListener("submit",function(e){e.preventDefault();ask(input.value).catch(function(){});});
 input.addEventListener("keydown",function(e){if((e.ctrlKey||e.metaKey)&&e.key==="Enter"){e.preventDefault();form.requestSubmit();}});
 document.querySelectorAll("[data-prompt]").forEach(function(b){b.addEventListener("click",function(){input.value=b.dataset.prompt;input.focus();});});
 clear.addEventListener("click",function(){if(pending)return;history=[];thread.replaceChildren();audioUrls.forEach(URL.revokeObjectURL);audioUrls=[];status.textContent="";input.value="";input.focus();});
 window.addEventListener("course-language-change",ui);ui();
 var mc=document.modelContext;if(mc?.registerTool){
  var lifecycle=new AbortController();
  mc.registerTool({name:"ask_course_study_tutor",title:"Ask the course study tutor",description:"Ask a general course question or request conceptual revision. The tutor uses the same moderation, source grounding and no-assignment-completion policy as the visible chat. Revision is limited to one session before current coverage. The question and recent chat are sent to the AI service.",inputSchema:{type:"object",properties:{question:{type:"string",minLength:1,maxLength:1600}},required:["question"],additionalProperties:false},annotations:{readOnlyHint:false,untrustedContentHint:true},execute:async function(x){if(typeof x.question!=="string"||!x.question.trim()||x.question.length>1600)throw new Error("Enter a valid study question.");input.value=x.question;return await ask(x.question);}}, {signal:lifecycle.signal});
  mc.registerTool({name:"read_study_tutor_scope",title:"Read study tutor scope",description:"Read the tutor's current course coverage and revision boundary without sending a message.",inputSchema:{type:"object",properties:{},additionalProperties:false},annotations:{readOnlyHint:true},execute:async function(){var r=await fetch("/api/tutor-status");return Object.assign(await r.json(),{selectedLanguage:lang()});}},{signal:lifecycle.signal});
  window.addEventListener("pagehide",function(){lifecycle.abort();},{once:true});
 }
}());
