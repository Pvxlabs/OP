#!/usr/bin/env python3
"""Loopback-only synthetic HTML, metadata-only result. No header/request logging."""
from http.server import HTTPServer,BaseHTTPRequestHandler
from pathlib import Path
import json,sys,time
root=Path(__file__).resolve().parent
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def do_GET(self):
        data=(root/'Resources/scroll-embedding.html').read_bytes()
        self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.end_headers();self.wfile.write(data)
    def do_POST(self):
        size=min(int(self.headers.get('Content-Length','0')),8192)
        obj=json.loads(self.rfile.read(size))
        keys=['durationMs','travel','title','messages','scrollTop','extent','viewport','visibility']
        safe={k:obj[k] for k in keys if k in obj};safe['receivedUTC']=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())
        (out/'safari-fixture.json').write_text(json.dumps(safe,indent=2))
        self.send_response(204);self.end_headers()
server=HTTPServer(('127.0.0.1',0),Handler)
(out/'server.json').write_text(json.dumps({'port':server.server_port}))
server.serve_forever()
