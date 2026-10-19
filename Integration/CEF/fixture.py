"""Synthetic loopback fixture only. Never records headers or website traffic."""
import http.server, pathlib, json, sys, datetime
root = pathlib.Path(sys.argv[1]); root.mkdir(parents=True, exist_ok=True)
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self):
        with (root/'fixture-requests.ndjson').open('a') as log:
            log.write(json.dumps({'path':self.path})+'\n')
        if self.path.startswith('/v1/'):
            historical = self.path.endswith('/task_historical')
            result = {'execution_ref':'exec_synthetic','status':'BLOCKED','summary':'Synthetic CLINX summary',
                      'validation':'Fixture validation only','blockers':'Synthetic blocker','next_state':'REVIEW',
                      'received_at':'2020-01-01T00:00:00Z' if historical else datetime.datetime.now(datetime.timezone.utc).isoformat(),
                      'text_truncated':False,'redaction':'PATHS_AND_RAW_RESULT_OMITTED'}
            task = {'schema_version':'1','task_ref':'task_historical' if historical else 'task_synthetic','execution_ref':'exec_synthetic',
                    'title':'Synthetic CLINX task','state':'BLOCKED','execution_state':'BLOCKED','codex_running':False,
                    'mutation_boundary':{'observer_read_only':True,'allowed_actions':[]},'final_result':result}
            if self.path.startswith('/v1/health'): value={'schema_version':'1','status':'OK','read_only':True}
            elif self.path.startswith('/v1/tasks?'): value={'schema_version':'1','items':[task]}
            else: value=task
            data=json.dumps(value).encode();self.send_response(200);self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data);return
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
<h1>OP CEF Integration · synthetic fixture</h1><input aria-label="Synthetic input" placeholder="Paste test">
<main><article data-talvt-turn-state="{state}"><div data-content-search-unit-key="fallback-turn-0:1:assistant" data-chatgpt-search-message-ids="{message}"><div data-chatgpt-selection-conversation-id="{conversation}" data-chatgpt-selection-message-id="{message}"><div data-dil-message-id="{message}"><pre>{body}</pre></div></div></div></article></main>
<span role="status">回答已完成</span>
<form id="composer" onsubmit="return false">
<div contenteditable="true" aria-label="Synthetic message"></div>
<button type="submit" aria-label="Send" disabled>Send synthetic message</button></form>
<style>[contenteditable]{{border:1px solid gray;min-height:32px;margin-top:20px}}</style>
<script>
const editor=document.querySelector('[contenteditable]'),form=document.getElementById('composer'),send=form.querySelector('button');
editor.addEventListener('input',()=>{{send.disabled=!editor.innerText.trim()||form.dataset.noSend==='true';}});
const historyKey='op-clinx-'+location.pathname;
const renderReceipt=text=>{{
 const user=document.createElement('div');user.dataset.contentSearchUnitKey='fixture:receipt:user';
 const content=document.createElement('span');content.textContent=text;user.append(content);
 if(text.includes('op_clinx_identification')) {{
   content.style.cssText='display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden';
   const expand=document.createElement('button');expand.textContent='Show more';expand.onclick=()=>{{content.style.cssText='';expand.textContent='Show less';}};user.append(expand);
 }}
 document.querySelector('main').append(user);
 const turn=document.createElement('article');turn.dataset.talvtTurnState='complete';
 const assistant=document.createElement('div');assistant.dataset.contentSearchUnitKey='fixture:receipt:assistant';
 if(text.startsWith('OP 自动识别任务 ')) {{
   const id=text.match(/\\[OP-CLINX-IDENTIFY:([A-Fa-f0-9-]+)\\]/)?.[1];
   const mode=form.dataset.identificationMode;
   const tasks=mode==='empty'?[]:[{{task_ref:mode==='historical'?'task_historical':'task_synthetic',execution_ref:mode==='mismatch'?'exec_wrong':'exec_synthetic',created_here:true}}];
   const code=document.createElement('code'),pre=document.createElement('pre');
   code.textContent=JSON.stringify({{op_clinx_identification:mode==='nonce'?'wrong':id,conversation_id:'{conversation}',tasks}});
   pre.append(code);assistant.append(pre);
 }} else assistant.textContent='Synthetic delivery acknowledged';
 turn.append(assistant);document.querySelector('main').append(turn);
}};
for(const text of JSON.parse(localStorage.getItem(historyKey)||'[]')) renderReceipt(text);
send.addEventListener('click',()=>{{
 const text=editor.innerText;editor.textContent='';send.disabled=true;
 if(form.dataset.suppressBubble==='true') return;
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
 if(action>=21&&action<=25) {{
   form.dataset.identificationMode=action===22?'mismatch':action===23?'historical':action===24?'empty':action===25?'nonce':'';
   const mid=crypto.randomUUID(),turn=document.createElement('article');turn.dataset.talvtTurnState='complete';
   const unit=document.createElement('div');unit.dataset.contentSearchUnitKey='fixture:new:assistant';unit.dataset.chatgptSearchMessageIds=mid;
   const selection=document.createElement('div');selection.dataset.chatgptSelectionConversationId='{conversation}';selection.dataset.chatgptSelectionMessageId=mid;
   const body=document.createElement('div');body.dataset.dilMessageId=mid;
   body.textContent=action===24?'CLINX documentation quote only, not a created execution.':'CLINX synthetic execution created and started.';
   selection.append(body);unit.append(selection);turn.append(unit);document.querySelector('main').append(turn);
 }}
}};</script>'''
        data = html.encode(); self.send_response(status); self.send_header('Content-Type','text/html; charset=utf-8'); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
server = http.server.ThreadingHTTPServer(('127.0.0.1',0), Handler)
(root/'port').write_text(str(server.server_port)); server.serve_forever()
