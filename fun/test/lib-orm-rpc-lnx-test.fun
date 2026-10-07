// lib-orm-rpc-lnx: the JSON-RPC ORM service on Linux (SQLite via lib-ado-lnx).
//
// Self-contained: a temp file DB is created, served over the poll(2) JSON-RPC
// server, and every assertion prints a boolean so the snapshot is stable.
//
// Sections:
//   1  OrmInit auto-builds the ORM schema from the database
//   2  OrmGet
//   3  OrmSave
//   4  OrmDelete
//   5  unknown method -> -32601

use 'fun/lib/lib-orm-rpc-lnx.fun';

var dbfile = '/tmp/fun-orm-rpc-lnx-test.sqlite';
try dbfile.move(); except end try;

var setup = ADO(dbfile);
setup.dontPrintSQL = true;
setup.Open();
setup.Execute('CREATE TABLE "User"(id INTEGER PRIMARY KEY, name TEXT, age INTEGER)');
setup.Execute('INSERT INTO "User"(name,age) VALUES(?,?)', false, ps: [[v: 'alice', dt: 9], [v: 30, dt: 1]]);
setup.Close();

var rpc = OrmRpc();
rpc.port = 0;
rpc.listen();
var p = rpc.LocalPort();

fun hasRe(s, re)
  result = false;
  if s =~ re then result = true; end if;
end fun;

fun call(port, method, params)
  var body = '{"jsonrpc":"2.0","id":1,"method":"' & method & '","params":' & params & '}';
  var c = ConnectSocket('127.0.0.1', port);
  var req = 'POST /JsonRpc/2.0 HTTP/1.1\r\nContent-Length: ' & body.length() & '\r\n\r\n' & body;
  SendAll(c, req.escape());
  result = c;
end fun;

fun pump(rpc, n)
  for i = 1 to n loop
    exit when rpc.runOnce(300) = 0;
  end loop;
end fun;

//--------------------------------------------------------------
// 1. OrmInit (schema read from the DB)
//--------------------------------------------------------------
var c1 = call(p, 'OrmInit', '{"connectionString":"' & dbfile & '"}');
pump(rpc, 6);
var r1 = RecvSome(c1, 8192);
?. 'orm init: ' & hasRe(r1, %"result":1%);
CloseSocket(c1);

//--------------------------------------------------------------
// 2. OrmGet
//--------------------------------------------------------------
var c2 = call(p, 'OrmGet', '{"User":{"name":"alice"}}');
pump(rpc, 6);
var r2 = RecvSome(c2, 8192);
?. 'orm get name: ' & hasRe(r2, %"name":"alice"%);
?. 'orm get age: ' & hasRe(r2, %"age":30%);
CloseSocket(c2);

//--------------------------------------------------------------
// 3. OrmSave
//--------------------------------------------------------------
var c3 = call(p, 'OrmSave', '{"User":[{"name":"bob","age":25}]}');
pump(rpc, 6);
var r3 = RecvSome(c3, 8192);
?. 'orm save rows: ' & hasRe(r3, %"rows":1%);
CloseSocket(c3);

//--------------------------------------------------------------
// 3b. OrmGet with no filter lists every row (multi-row DObject.Get,
//     alice + bob are both present here)
//--------------------------------------------------------------
var c3b = call(p, 'OrmGet', '{"User":{}}');
pump(rpc, 6);
var r3b = RecvSome(c3b, 8192);
?. 'orm get all rows: ' & hasRe(r3b, %"bob"%) & '/' & hasRe(r3b, %"alice"%);
CloseSocket(c3b);

//--------------------------------------------------------------
// 4. OrmDelete
//--------------------------------------------------------------
var c4 = call(p, 'OrmDelete', '{"User":{"name":"bob"}}');
pump(rpc, 6);
var r4 = RecvSome(c4, 8192);
?. 'orm delete rows: ' & hasRe(r4, %"rows":1%);
CloseSocket(c4);

//--------------------------------------------------------------
// 5. unknown method
//--------------------------------------------------------------
var c5 = call(p, 'OrmNope', '{}');
pump(rpc, 6);
var r5 = RecvSome(c5, 8192);
?. 'orm unknown method: ' & hasRe(r5, %"code":-32601%);
CloseSocket(c5);

rpc.stop();
dbfile.move();
?. 'done';
