"""Loopback-only synthetic 429 fixture. Never reads or logs request headers."""
import http.server
import pathlib
import sys


class Fixture(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'<!doctype html><main><p>Too many requests</p></main>'
        self.send_response(429)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Fixture)
pathlib.Path(sys.argv[1]).write_text(str(server.server_port))
server.serve_forever()
