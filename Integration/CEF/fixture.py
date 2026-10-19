"""Synthetic loopback fixture only. Never records headers or website traffic."""
import http.server, pathlib, json, sys
root = pathlib.Path(sys.argv[1]); root.mkdir(parents=True, exist_ok=True)
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self):
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
<script>window.fixture = action => {{
 const article=document.querySelector('article'),pre=document.querySelector('pre');
 if(action===0) pre.textContent='Unable to load this response';
 if(action===1) {{article.dataset.talvtTurnState='in_progress';pre.textContent='Synthetic partial stream';}}
 if(action===2) {{article.dataset.talvtTurnState='complete';pre.textContent='Synthetic protected response. 中文。\\n'.repeat(150);}}
 if(action===3) pre.textContent='';
 if(action===7) {{ const f=document.createElement('iframe');f.srcdoc='<main><article data-talvt-turn-state="complete"><div data-content-search-unit-key="0:assistant" data-chatgpt-search-message-ids="66666666-6666-4666-8666-666666666666"><div data-chatgpt-selection-conversation-id="{conversation}" data-chatgpt-selection-message-id="66666666-6666-4666-8666-666666666666"><div data-dil-message-id="66666666-6666-4666-8666-666666666666">Subframe must never be stored</div></div></div></article></main>';document.body.append(f); }}
 if(action===8) {{document.querySelector('[data-chatgpt-selection-conversation-id]').setAttribute('data-chatgpt-selection-conversation-id','');}}
 if(action===4) {{document.querySelector('[data-chatgpt-selection-conversation-id]').dataset.chatgptSelectionConversationId='99999999-9999-4999-8999-999999999999';pre.textContent='must reject identity mismatch';}}
}};</script>'''
        data = html.encode(); self.send_response(status); self.send_header('Content-Type','text/html; charset=utf-8'); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
server = http.server.ThreadingHTTPServer(('127.0.0.1',0), Handler)
(root/'port').write_text(str(server.server_port)); server.serve_forever()
