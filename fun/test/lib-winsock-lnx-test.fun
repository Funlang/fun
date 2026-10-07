// lib-winsock-lnx: UDP + TCP + DNS + HTTP/WebSocket test (self-contained, loopback).
//
// Everything is synchronous on the calling thread (poll(2)); ports are ephemeral
// and every assertion prints a boolean, so the snapshot is deterministic.
//
// Sections:
//   1-6  UDP server (bind/LocalPort/Send/RunOnce/Run/Stop, bind failure)
//   7    hostname resolution (getaddrinfo)
//   8    raw TCP (ListenSocket/ConnectSocket/AcceptSocket/SendAll/RecvSome/
//        PeerAddr/Shutdown/EOF)
//   9    HTTP server (GET/POST/404 through Server.HTTP + Reply helpers)
//   10   WebSocket handshake + one masked text frame
//   11   HTTP client mode (Connect + SendEx + onGet)
//   12   HTTP blocking Run() loop stopped from inside the handler
//   13   simple async: Post + After/Every timers on the poll loop

use 'fun/lib/lib-winsock-lnx.fun';

// `s =~ re` only yields a boolean in boolean context, so wrap it.
fun hasRe(s, re)
  result = false;
  if s =~ re then result = true; end if;
end fun;

// drive the HTTP server until a poll round finds nothing to do
fun pumpWeb(w, n)
  for i = 1 to n loop
    exit when w.RunOnce(300) = 0;
  end loop;
end fun;

//--------------------------------------------------------------
// 1. bind on port 0, learn the ephemeral port
//--------------------------------------------------------------
var got = nil;
var srv = Server.UDP('127.0.0.1', 0, (data, ip, port){
  got = new [data: data, ip: ip, port: port];
  srv.Send(ip, port, 'echo:' & data);
});
?. 'start: ' & srv.Start();
var port = srv.LocalPort();
?. 'bound to a port: ' & (port > 0);

//--------------------------------------------------------------
// 2. client -> server, one datagram
//--------------------------------------------------------------
var cli = UDPSocket();
?. 'sendto 9 bytes: ' & (SendTo(cli, '127.0.0.1', port, 'hello-udp') = 9);
?. 'runonce rc: ' & srv.RunOnce(1000);
?. 'server got data: ' & (got.data = 'hello-udp');
?. 'server got ip: ' & (got.ip = '127.0.0.1');
?. 'server got client port: ' & (got.port > 0);

//--------------------------------------------------------------
// 3. server -> client (the echo produced in the callback)
//--------------------------------------------------------------
var r = RecvFrom(cli, 1000);
?. 'client got echo: ' & (r.data = 'echo:hello-udp');
?. 'echo source: ' & (r.ip = '127.0.0.1' and r.port = port);

//--------------------------------------------------------------
// 4. poll timeout returns nil
//--------------------------------------------------------------
?. 'timeout returns nil: ' & (RecvFrom(cli, 100) = nil);

//--------------------------------------------------------------
// 5. blocking Run() loop, stopped from inside onGet after 3 datagrams
//--------------------------------------------------------------
var n = 0;
var loopSrv = Server.UDP('127.0.0.1', 0, (data, ip, port){
  n += 1;
  loopSrv.Send(ip, port, 'ack' & n);
  if n >= 3 then loopSrv.Stop(); end if;
});
loopSrv.Start();
var lport = loopSrv.LocalPort();
for k = 1 to 3 do
  SendTo(cli, '127.0.0.1', lport, 'm' & k);
end do;
loopSrv.Run(1000);          // returns when the callback calls Stop()
?. 'run handled 3: ' & (n = 3);
var acks = '';
for k = 1 to 3 do
  acks &= RecvFrom(cli, 1000).data & ' ';
end do;
?. 'acks in order: ' & (acks = 'ack1 ack2 ack3 ');
loopSrv.Stop();

//--------------------------------------------------------------
// 6. bind failure is raised, not silent
//--------------------------------------------------------------
var bad = Server.UDP('8.8.8.8', 0, (data, ip, port){ });
var raised = false;
try
  bad.Start();
except
  raised = true;
end try;
?. 'bind failure raised: ' & raised;

srv.Stop();
CloseSocket(cli);

//--------------------------------------------------------------
// 7. hostname resolution
//--------------------------------------------------------------
?. 'dns localhost: ' & (getHostByName('localhost') = '127.0.0.1');
?. 'dns numeric: ' & (getHostByName('10.1.2.3') = '10.1.2.3');

//--------------------------------------------------------------
// 8. raw TCP
//--------------------------------------------------------------
var ls = ListenSocket('127.0.0.1', 0, nil);
?. 'tcp listen port: ' & (LocalAddr(ls).port > 0);
var cc = ConnectSocket('127.0.0.1', LocalAddr(ls).port);
?. 'tcp connect: ' & (cc > 0);
var ss = AcceptSocket(ls);
?. 'tcp accept: ' & (ss > 0);
?. 'tcp sendall: ' & (SendAll(cc, 'ping') = 4);
?. 'tcp recvsome: ' & (RecvSome(ss, 16) = 'ping');
?. 'tcp peeraddr: ' & (PeerAddr(cc).ip = '127.0.0.1');
Shutdown(cc, nil);
?. 'tcp recv eof: ' & (RecvSome(ss, 16) = nil);
CloseSocket(cc); CloseSocket(ss); CloseSocket(ls);

//--------------------------------------------------------------
// 9. HTTP server
//--------------------------------------------------------------
var seen = new [];
var web = Server.HTTP('127.0.0.1', 0, (req, header, body, sock, args){
  seen.@add(new [req: req, body: body, ws: args and args.webSocket]);
  if args and args.webSocket then
    web.Reply('world:' & body, sock);
  elsif req = '/404' then
    web.Reply404('nope', sock);
  else
    web.Reply200('hi ' & body, sock);
  end if;
});
web.Start();
var wp = web.LocalPort();
?. 'http port: ' & (wp > 0);

// GET without a body
var c1 = ConnectSocket('127.0.0.1', wp);
SendAll(c1, 'GET /hello HTTP/1.1\r\nHost: x\r\n\r\n'.escape());
pumpWeb(web, 5);
var r1 = RecvSome(c1, 4096);
?. 'http 200: ' & hasRe(r1, %^HTTP/1\.1\x20200%);
?. 'http body: ' & hasRe(r1, %\r\n\r\nhi\x20%);
?. 'http req seen: ' & (seen[0].req = '/hello');

// POST with a body
var c2 = ConnectSocket('127.0.0.1', wp);
SendAll(c2, 'POST /echo HTTP/1.1\r\nContent-Length: 5\r\n\r\nhello'.escape());
pumpWeb(web, 5);
var r2 = RecvSome(c2, 4096);
?. 'http post body: ' & hasRe(r2, %\r\n\r\nhi\x20hello%);
?. 'http post seen: ' & (seen[1].body = 'hello');

// 404
var c3 = ConnectSocket('127.0.0.1', wp);
SendAll(c3, 'GET /404 HTTP/1.1\r\n\r\n'.escape());
pumpWeb(web, 5);
var r3 = RecvSome(c3, 4096);
?. 'http 404: ' & hasRe(r3, %^HTTP/1\.1\x20404%);
CloseSocket(c1); CloseSocket(c2); CloseSocket(c3);

//--------------------------------------------------------------
// 10. WebSocket handshake + one masked text frame
//--------------------------------------------------------------
var c4 = ConnectSocket('127.0.0.1', wp);
SendAll(c4, 'GET /ws HTTP/1.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n'.escape());
pumpWeb(web, 5);
var hs = RecvSome(c4, 4096);
?. 'ws 101: ' & hasRe(hs, %^HTTP/1\.1\x20101%);
?. 'ws accept: ' & hasRe(hs, %s3pPLMBiTxaQ9kYGzzhZRbK\+xOo=%);

var mask = new [0x12, 0x34, 0x56, 0x78];
var maskBytes = 0x12.toChar() & 0x34.toChar() & 0x56.toChar() & 0x78.toChar();
var frame = 0x81.toChar() & (0x80 bit or 5).toChar() & maskBytes & web.wsEncode('hello', mask);
?. 'ws frame sent: ' & (SendAll(c4, frame) = 11);
pumpWeb(web, 5);
?. 'ws onGet: ' & (seen[3].ws and seen[3].body = 'hello');
var reply = RecvSome(c4, 4096);
?. 'ws reply: ' & (reply.length() = 13 and reply.toByte(0) = 0x81 and reply.toByte(1) = 11 and reply.substr(2) = 'world:hello');

CloseSocket(c4);
web.Stop();

//--------------------------------------------------------------
// 11. HTTP client mode (Connect + SendEx + onGet(status, ...))
//--------------------------------------------------------------
var csrv = Server.HTTP('127.0.0.1', 0, (req, header, body, sock, args){
  csrv.Reply200('pong', sock);
});
csrv.Start();
var cstat = nil;
var clis = Server.HTTP('127.0.0.1', csrv.LocalPort(), (res, header, body, sock, args){
  cstat = res;
});
?. 'http client connect: ' & clis.Connect(nil);
clis.SendEx('GET /x HTTP/1.1\r\nHost: y\r\n\r\n'.escape());
for i = 1 to 4 do csrv.RunOnce(200); end do;
for i = 1 to 4 do clis.RunOnce(200); end do;
?. 'http client status: ' & (cstat = '200');
clis.Stop(); csrv.Stop();

//--------------------------------------------------------------
// 12. HTTP blocking Run() loop, stopped from inside the handler
//--------------------------------------------------------------
var rn = 0;
var runSrv = Server.HTTP('127.0.0.1', 0, (req, header, body, sock, args){
  runSrv.Reply200('ok', sock);
  rn += 1;
  if rn >= 3 then runSrv.Stop(); end if;
});
runSrv.Start();
var rp = runSrv.LocalPort();
var a1 = ConnectSocket('127.0.0.1', rp);
var a2 = ConnectSocket('127.0.0.1', rp);
var a3 = ConnectSocket('127.0.0.1', rp);
var rq = 'GET /a HTTP/1.1\r\n\r\n'.escape();
SendAll(a1, rq); SendAll(a2, rq); SendAll(a3, rq);
runSrv.Run(1000);           // returns when the handler calls Stop()
?. 'http run handled 3: ' & (rn = 3);
CloseSocket(a1); CloseSocket(a2); CloseSocket(a3);

//--------------------------------------------------------------
// 13. simple async: Post + After/Every timers on the poll loop
//--------------------------------------------------------------
var fired = new [];
var asrv = Server.HTTP('127.0.0.1', 0, (req, header, body, sock, args){ });
asrv.Start();
asrv.Post((){ fired.@add('post'); });
asrv.After(60, (){ fired.@add('after'); asrv.Stop(); });
asrv.Every(5000, (){ fired.@add('every'); });   // far out; must not fire before Stop
asrv.Run(5000);                                  // returns when After calls Stop()
?. 'async post fired: ' & ('post' in fired);
?. 'async after fired: ' & ('after' in fired);
?. 'async every not early: ' & not ('every' in fired);
asrv.Stop();

var uf = new [];
var usrv = Server.UDP('127.0.0.1', 0, (data, ip, port){ });
usrv.Start();
usrv.After(50, (){ uf.@add('t'); usrv.Stop(); });
usrv.Run(5000);
?. 'udp async timer: ' & ('t' in uf);
usrv.Stop();

?. 'done';
