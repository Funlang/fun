// lib-jsonrpc-lnx: JSON-RPC 2.0 over HTTP on the Linux poll(2) server.
//
// Self-contained and single-threaded: the server is driven with listen() +
// runOnce(), and every assertion prints a boolean, so the snapshot is stable.
//
// Sections:
//   1  listen() binds and reports an ephemeral port
//   2  Rpc_Test dispatch returns result/data
//   3  unknown method -> -32601
//   4  missing params/args -> -32602
//   5  missing method -> -32600
//   6  off-route request closes the connection
//   7  blocking start() returns when a timer calls stop()

use 'fun/lib/lib-jsonrpc-lnx.fun';

// `s =~ re` only yields a boolean in boolean context, so wrap it.
fun hasRe(s, re)
  result = false;
  if s =~ re then result = true; end if;
end fun;

// drive one request to completion: accept, read, dispatch, reply
fun pump(rpc, n)
  for i = 1 to n loop
    exit when rpc.runOnce(300) = 0;
  end loop;
end fun;

fun post(port, path, body)
  var c = ConnectSocket('127.0.0.1', port);
  var req = 'POST ' & path & ' HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: ' & body.length() & '\r\n\r\n' & body;
  SendAll(c, req.escape());
  result = c;
end fun;

//--------------------------------------------------------------
// 1. listen + ephemeral port
//--------------------------------------------------------------
var rpc = JsonRpc();
rpc.port = 0;
?. 'listen: ' & rpc.listen();
var p = rpc.LocalPort();
?. 'port > 0: ' & (p > 0);

//--------------------------------------------------------------
// 2. Test method
//--------------------------------------------------------------
var c1 = post(p, JsonRpcRoute, '{"jsonrpc":"2.0","method":"Test","id":1,"params":{}}');
pump(rpc, 5);
var r1 = RecvSome(c1, 4096);
?. 'rpc 200: ' & hasRe(r1, %^HTTP/1\.1\x20200%);
?. 'rpc result: ' & hasRe(r1, %"result":1%);
?. 'rpc data: ' & hasRe(r1, %"data":"Test\x20called\."%);
CloseSocket(c1);

//--------------------------------------------------------------
// 3. unknown method
//--------------------------------------------------------------
var c2 = post(p, JsonRpcRoute, '{"jsonrpc":"2.0","method":"Nope","id":2,"params":{}}');
pump(rpc, 5);
var r2 = RecvSome(c2, 4096);
?. 'unknown method -32601: ' & hasRe(r2, %"code":-32601%);
?. 'unknown method msg: ' & hasRe(r2, %Method\sNope\snot\sfound%);
CloseSocket(c2);

//--------------------------------------------------------------
// 4. no params / no args
//--------------------------------------------------------------
var c3 = post(p, JsonRpcRoute, '{"jsonrpc":"2.0","method":"Test","id":3}');
pump(rpc, 5);
var r3 = RecvSome(c3, 4096);
?. 'invalid params -32602: ' & hasRe(r3, %"code":-32602%);
CloseSocket(c3);

//--------------------------------------------------------------
// 5. no method -> invalid request
//--------------------------------------------------------------
var c4 = post(p, JsonRpcRoute, '{"jsonrpc":"2.0","id":4,"params":{}}');
pump(rpc, 5);
var r4 = RecvSome(c4, 4096);
?. 'invalid request -32600: ' & hasRe(r4, %"code":-32600%);
CloseSocket(c4);

//--------------------------------------------------------------
// 6. off-route request: the handler closes the socket (EOF on the client)
//--------------------------------------------------------------
var c5 = ConnectSocket('127.0.0.1', p);
SendAll(c5, 'GET /nope HTTP/1.1\r\n\r\n'.escape());
pump(rpc, 5);
?. 'off-route closed: ' & (RecvSome(c5, 1000) = nil);
CloseSocket(c5);

rpc.stop();
?. 'stopped: ' & (rpc.http = nil);

//--------------------------------------------------------------
// 7. blocking start() returns when a timer calls stop()
//--------------------------------------------------------------
var rpc2 = JsonRpc();
rpc2.port = 0;
rpc2.listen();
rpc2.http.After(50, (){ rpc2.stop(); });
rpc2.start(200);            // waits ~50ms, then the timer stops the loop
?. 'blocking start returned: ' & (rpc2.http = nil);

?. 'done';
