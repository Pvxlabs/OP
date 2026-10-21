"""Synthetic loopback fixture only. Never records headers or website traffic."""
import http.server, pathlib, json, sys, time
root = pathlib.Path(sys.argv[1]); root.mkdir(parents=True, exist_ok=True)
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self):
        with (root/'fixture-requests.ndjson').open('a') as log:
            log.write(json.dumps({'path':self.path})+'\n')
        if self.path == '/backend-api/conversation/synthetic-timing':
            time.sleep(0.15)
            body = b'{"synthetic":true}'
            self.send_response(200); self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body))); self.end_headers()
            self.wfile.write(body)
            return
        if self.path.startswith('/transport/'):
            case = self.path.rsplit('/', 1)[-1]
            body = b'data: synthetic partial payload\n\n'
            self.send_response(429 if case == 'http-error' else 200)
            self.send_header('Content-Type', 'text/plain' if case == 'http-error' else 'text/event-stream')
            self.send_header('Content-Length', str(len(body) + (100 if case in ('truncated', 'cancel') else 0)))
            self.send_header('X-Fixture-Secret', 'must-not-be-logged')
            self.end_headers()
            self.wfile.write(body); self.wfile.flush()
            if case == 'cancel': time.sleep(1)
            self.close_connection = True
            return
        conversation = self.path.split('?',1)[0].split('/')[-1]
        try: mode = json.loads((root/'mode.json').read_text()).get(conversation, 'normal')
        except (FileNotFoundError, ValueError): mode = 'normal'
        status = int(mode) if mode in ('403','429') else 200
        message = '22222222-2222-4222-8222-222222222222'
        body = ('Synthetic protected response. 中文。\n' * 150)
        state = 'in_progress' if mode == 'stream' else 'complete'
        if mode in ('403','429','error'): body = 'Unable to load this response'
        if mode == 'blank': body = ''
        # Same website identity profile already used by the WK tests; no fake native transport.
        html = f'''<!doctype html><meta charset="utf-8"><title>OP CEF Synthetic — {conversation[-4:]}</title>
<style>body{{font:16px system-ui;margin:32px;}} pre{{white-space:pre-wrap}} </style>
<h1>OP CEF Integration · synthetic fixture</h1><input aria-label="Synthetic input" placeholder="Paste test"><button onclick="window.fixture(1);setTimeout(()=>window.fixture(2),5000)">Start 5-second reply</button>
<main><article data-talvt-turn-state="{state}"><div data-content-search-unit-key="fallback-turn-0:1:assistant" data-chatgpt-search-message-ids="{message}"><div data-chatgpt-selection-conversation-id="{conversation}" data-chatgpt-selection-message-id="{message}"><div data-dil-message-id="{message}"><pre>{body}</pre></div></div></div></article></main>
<span role="status">回答已完成</span><button hidden data-testid="stop-button" aria-label="Stop generating" onclick="document.querySelector('article').dataset.talvtTurnState='complete'">Stop synthetic</button>
<form id="composer" onsubmit="return false">
<div contenteditable="true" aria-label="Synthetic message"></div>
<button type="submit" aria-label="Send" disabled>Send synthetic message</button></form>
<style>[contenteditable]{{border:1px solid gray;min-height:32px;margin-top:20px}}
body:has(form[data-contents-bubbles="true"]) [data-content-search-unit-key$=":user"] {{display:contents}}
body:has(form[data-hidden-bubbles="true"]) [data-content-search-unit-key$=":user"] {{display:none}}
</style>
<script>
const editor=document.querySelector('[contenteditable]'),form=document.getElementById('composer'),send=form.querySelector('button');
editor.addEventListener('input',()=>{{send.disabled=!editor.innerText.trim()||form.dataset.noSend==='true';}});
const historyKey='op-query-'+location.pathname;
let receipt=0;
const renderReceipt=text=>{{
 const user=document.createElement('div');user.dataset.contentSearchUnitKey='fixture:receipt:'+ ++receipt +':user';
 const content=document.createElement('span');content.textContent=text;user.append(content);
 document.querySelector('main').append(user);
 const turn=document.createElement('article');turn.dataset.talvtTurnState='complete';
 const assistant=document.createElement('div');assistant.dataset.contentSearchUnitKey='fixture:receipt:assistant';
 assistant.textContent='Synthetic query acknowledged';
 const consultation=text.match(/OP_CONSULT_REQUEST:([0-9a-f-]{{36}})/);
 if(consultation) {{
   user.dataset.contentSearchUnitKey='fixture:'+consultation[1]+':user';
   turn.dataset.talvtTurnState='in_progress';assistant.textContent='';
   const id=crypto.randomUUID(),scope=document.createElement('div'),body=document.createElement('div');
   assistant.dataset.chatgptSearchMessageIds=id;
   scope.dataset.chatgptSelectionConversationId='{conversation}';scope.dataset.chatgptSelectionMessageId=id;
   body.dataset.dilMessageId=id;body.textContent='Generating synthetic answer';
   scope.append(body);assistant.append(scope);
   setTimeout(()=>{{body.textContent='OP_CONSULT_REQUEST:'+consultation[1]+'\\nOP_SYNTHETIC_SUM=42';turn.dataset.talvtTurnState='complete';}},700);
 }}
 turn.append(assistant);document.querySelector('main').append(turn);
}};
for(const text of JSON.parse(localStorage.getItem(historyKey)||'[]')) renderReceipt(text);
send.addEventListener('click',()=>{{
 const text=editor.innerText;editor.textContent='';send.disabled=true;
 if(form.dataset.suppressBubble==='true') {{
  for(const user of document.querySelectorAll('main > [data-content-search-unit-key$=":user"], main > [data-message-author-role="user"]')) user.replaceWith(user.cloneNode(true));
  return;
 }}
 if(form.dataset.replaceReceipt==='true') document.querySelector('main > [data-content-search-unit-key$=":user"]')?.remove();
 renderReceipt(text);
 const saved=JSON.parse(localStorage.getItem(historyKey)||'[]');saved.push(text);localStorage.setItem(historyKey,JSON.stringify(saved));
}});
</script>
<script>window.fixture = action => {{
 const article=document.querySelector('article'),pre=document.querySelector('pre');
 if(action===0) pre.textContent='Unable to load this response';
 if(action===1) {{article.dataset.talvtTurnState='in_progress';pre.textContent='Synthetic partial stream';}}
 if(action===2) {{article.dataset.talvtTurnState='complete';pre.textContent='Synthetic protected response. 中文。\\n'.repeat(150);}}
 if(action===3) pre.textContent='';
 if(action===7) {{ const f=document.createElement('iframe');f.srcdoc='<main><article data-talvt-turn-state="complete"><div data-content-search-unit-key="0:assistant" data-chatgpt-search-message-ids="66666666-6666-4666-8666-666666666666"><div data-chatgpt-selection-conversation-id="{conversation}" data-chatgpt-selection-message-id="66666666-6666-4666-8666-666666666666"><div data-dil-message-id="66666666-6666-4666-8666-666666666666">Subframe must never be stored</div></div></div></article></main>';document.body.append(f); }}
 if(action===8) {{document.querySelector('[data-chatgpt-selection-conversation-id]').setAttribute('data-chatgpt-selection-conversation-id','');}}
 if(action===4) {{document.querySelector('[data-chatgpt-selection-conversation-id]').dataset.chatgptSelectionConversationId='99999999-9999-4999-8999-999999999999';pre.textContent='must reject identity mismatch';}}
 if(action===10) editor.textContent='Keep this draft';
 if(action===11) editor.textContent='';
 if(action===12) article.dataset.talvtTurnState='in_progress';
 if(action===13) article.dataset.talvtTurnState='complete';
 if(action===14) {{const dialog=document.createElement('div');dialog.id='test-modal';dialog.setAttribute('role','dialog');dialog.textContent='Modal';document.body.append(dialog);}}
 if(action===15) document.getElementById('test-modal')?.remove();
 if(action===16) {{const image=document.createElement('div');image.dataset.testid='attachment-preview';image.textContent='Attachment';form.append(image);}}
 if(action===17) form.querySelector('[data-testid="attachment-preview"]')?.remove();
 if(action===18) form.dataset.noSend='true';
 if(action===19) {{delete form.dataset.noSend;editor.textContent='';}}
 if(action===20) form.dataset.suppressBubble='true';
 if(action===21) {{delete form.dataset.suppressBubble;}}
 if(action===24) {{editor.addEventListener('input',()=>{{editor.textContent='User changed draft';}},{{once:true}});}}
 if(action===25) {{editor.addEventListener('input',()=>{{history.replaceState(null,'','/c/99999999-9999-4999-8999-999999999999');}},{{once:true}});}}
 if(action===28) document.querySelector('[aria-label="Stop generating"]').click();
 if(action===33) form.dataset.contentsBubbles='true';
 if(action===34) form.dataset.hiddenBubbles='true';
 if(action===35) delete form.dataset.hiddenBubbles;
 if(action===36) form.dataset.replaceReceipt='true';
 if(action===37) {{
  for(const node of document.querySelectorAll('main > [data-content-search-unit-key$=":user"]')) {{
   node.dataset.messageAuthorRole='user';node.removeAttribute('data-content-search-unit-key');
  }}
  form.dataset.suppressBubble='true';
 }}
 if(action===26) {{editor.addEventListener('input',()=>{{document.getElementById('test-modal')?.remove();window.fixture(14);}},{{once:true}});}}
 if(action>=29 && action<=32) {{
   const kind=['normal','truncated','http-error','cancel'][action-29];
   const controller=new AbortController();
   fetch('/transport/'+kind,{{signal:controller.signal,headers:{{'X-Fixture-Secret':'must-not-be-logged'}}}})
     .then(response=>response.text()).catch(()=>{{}});
   if(kind==='cancel') setTimeout(()=>controller.abort(),100);
 }}
}};</script>
<script>window.syntheticTimingRead = () => fetch('/backend-api/conversation/synthetic-timing');</script>'''
        data = html.encode(); self.send_response(status); self.send_header('Content-Type','text/html; charset=utf-8'); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
server = http.server.ThreadingHTTPServer(('127.0.0.1',0), Handler)
(root/'port').write_text(str(server.server_port)); server.serve_forever()
