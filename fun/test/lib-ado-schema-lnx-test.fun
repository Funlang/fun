// lib-ado-schema-lnx on SQLite: OpenSchema -> Filter/Format -> ToSchema ->
// lib-orm CRUD (auto-generated schema, including a foreign-key relation).
// Uses a temp file DB (a second :memory: connection could not see the tables).
use 'fun/lib/lib-orm-pro.fun';
use 'fun/lib/lib-ado-schema-lnx.fun';

var dbfile = '/tmp/fun-ado-schema-lnx-test.sqlite';
try dbfile.move(); except end try;

var db = ADO(dbfile);
db.dontPrintSQL = true;
db.Open();
db.Execute('CREATE TABLE "User"(id INTEGER PRIMARY KEY, name TEXT, age INTEGER)');
db.Execute('CREATE TABLE "Order"(id INTEGER PRIMARY KEY, user_id INTEGER REFERENCES "User"(id), total INTEGER)');
db.Execute('INSERT INTO "User"(name,age) VALUES(?,?)', false, ps: [[v: 'alice', dt: 9], [v: 30, dt: 1]]);
db.Close();

var s = Schema(dbfile);
var g = s.Get();
?. 'tables=' & g.Tables.@count() & ' fields=' & g.Fields.@count();

db.Open();
db.schema = s.ToSchema();
?. 'user fields=' & db.schema.User.@Fields.@count() & ' autokey=' & db.schema.User.@AutoKey;
?. 'order parent=' & db.schema.Order.@Parent.User.@Keys.id;
?. 'user children=' & db.schema.User.@Children.Order.@Keys.user_id;

var gg = OrmGet(db, new [User: new [name: 'alice']]);
?. 'get=' & gg.User.@count() & ' age=' & gg.User[0].age;

var r = OrmSave(db, new [User: new [[name: 'bob', age: 25]]]);
?. 'insert rows=' & r.User.rows & ' autoId=' & r.User.autoId;

var r2 = OrmUpdate(db, new [User: new [Set: new [age: 31], Where: new [name: 'bob']]]);
?. 'update rows=' & r2.User.rows;

var r3 = OrmDelete(db, new [User: new [name: 'bob']]);
?. 'delete rows=' & r3.User.rows;

db.Close();
dbfile.move();
?. 'done';
