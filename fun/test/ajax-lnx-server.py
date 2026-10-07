#!/usr/bin/env python3
# Deterministic HTTP fixture for run-ajax-lnx.sh. Started by the shell wrapper
# with:  ajax-lnx-server.py <port> <ready-marker-file>
# Writes the marker once it is listening, then serves fixed responses.
import http.server, socketserver, sys, os

port = int(sys.argv[1]) if len(sys.argv) > 1 else 18731
marker = sys.argv[2] if len(sys.argv) > 2 else ''


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype='text/plain', extra=None):
        b = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(b)))
        self.send_header('X-Test', 'yes')
        if extra:
            for k, v in extra.items():
                self.send_header(k, v)
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path.startswith('/hello'):
            self._send(200, 'hello world')
        elif self.path == '/hdr':
            self._send(200, 'xc=' + self.headers.get('X-Custom', ''))
        elif self.path == '/redir':
            self._send(302, '', extra={'Location': '/hello'})
        elif self.path == '/missing':
            self._send(404, 'nope')
        elif self.path == '/file.bin':
            self._send(200, b'\x00\x01\x02\xff', 'application/octet-stream')
        else:
            self._send(200, 'root')

    def do_POST(self):
        n = int(self.headers.get('Content-Length', '0'))
        body = self.rfile.read(n).decode()
        self._send(200, 'echo:' + body + '|ua:' + self.headers.get('User-Agent', ''))


socketserver.TCPServer.allow_reuse_address = True
srv = socketserver.TCPServer(('127.0.0.1', port), H)
if marker:
    with open(marker, 'w') as f:
        f.write('ready')
srv.serve_forever()
