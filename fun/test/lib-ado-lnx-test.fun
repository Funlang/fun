// lib-ado-lnx on SQLite: raw SQL, parameters, transactions, schema, and the
// lib-orm stack end to end. Everything runs in-memory, so the output is
// deterministic and there is no file to clean up.
use 'fun/lib/lib-ado-lnx.fun';
use 'fun/lib/lib-orm-pro.fun';
use 'fun/lib/lib-utils.fun';

var db = ADO(':memory:');
db.dontPrintSQL = true;
db.Open();

// ---- raw SQL ----
db.Execute('CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT, n INTEGER)');
db.Execute("INSERT INTO t(name,n) VALUES('alice',42)");
db.Execute("INSERT INTO t(name,n) VALUES('bob',7)");

var rows = db.Execute('SELECT id,name,n FROM t ORDER BY id', false);
?. 'select count=' & rows.@count();
for r in rows do
  ?. '  ' & r.id & ':' & r.name & ':' & r.n;
end do;

// positional parameters
var p = db.Execute('SELECT name FROM t WHERE n > ?', false, ps: [[v: 10, dt: 1]]);
?. 'param=' & p.@count() & ':' & p[0].name;

// rsNext: INSERT ...; SELECT last_insert_rowid()
var a = db.Execute("INSERT INTO t(name,n) VALUES('carol',1); SELECT last_insert_rowid() AS autoId", true);
?. 'autoId=' & a[0].autoId;

// affected rows
var u = db.Execute('UPDATE t SET n = 0 WHERE n > 0', false);
?. 'updated=' & u[0].rows;

// transactions
db.Begin();
db.Execute("INSERT INTO t(name,n) VALUES('dave',9)");
db.Rollback();
var c1 = db.Execute('SELECT COUNT(*) AS c FROM t', false);
?. 'rollback=' & c1[0].c;
db.Begin();
db.Execute("INSERT INTO t(name,n) VALUES('eve',9)");
db.Commit();
var c2 = db.Execute('SELECT COUNT(*) AS c FROM t', false);
?. 'commit=' & c2[0].c;

// blob bytes round trip
db.Execute('CREATE TABLE b(v BLOB)');
db.Execute('INSERT INTO b VALUES(?)', false, ps: [[v: '\x00\x01\x02\xff'.escape(), dt: 11]]);
var br = db.Execute('SELECT v FROM b', false);
?. 'blob=' & str2hex(br[0].v);

// null and float columns
db.Execute('INSERT INTO b VALUES(?)', false, ps: [[v: nil, dt: 9]]);
var bn = db.Execute('SELECT v FROM b', false);
?. 'null=' & (bn[1].v = nil);

// ---- OpenSchema ----
var tabs = db.OpenSchema(adSchemaTables);
?. 'tables=' & tabs.@count() & ':' & tabs[0].TABLE_NAME;
var cols = db.OpenSchema(adSchemaColumns);
?. 'columns=' & cols.@count() & ':' & cols[0].COLUMN_NAME & ':' & cols[0].DATA_TYPE;
var pks = db.OpenSchema(adSchemaPrimaryKeys);
?. 'pkeys=' & pks.@count() & ':' & pks[0].COLUMN_NAME;

// ---- lib-orm on SQLite ----
db.Execute('DROP TABLE t');
db.Execute('DROP TABLE b');
db.Execute('CREATE TABLE "User"(id INTEGER PRIMARY KEY, name TEXT, age INTEGER)');

fun F(alias, name, dt, isP, isAuto)
  result = new [Alias: alias, Name: name, DataType: dt, IsPrimary: isP, IsAutoId: isAuto];
end fun;

db.schema = new [
  User: new [
    Alias: 'User', Name: 'User', Schema: '',
    @Fields: new [
      id:   F('id',   'id',   1, 1, 1),
      name: F('name', 'name', 9, 0, 0),
      age:  F('age',  'age',  1, 0, 0)
    ]
  ]
];

var r1 = OrmSave(db, new [User: new [[name: 'alice', age: 30], [name: 'bob', age: 25]]]);
?. 'orm insert rows=' & r1.User.rows & ' autoId=' & r1.User.autoId;

var g = OrmGet(db, new [User: new [name: 'alice']]);
?. 'orm get=' & g.User.@count() & ' age=' & g.User[0].age;

var r2 = OrmUpdate(db, new [User: new [Set: new [age: 31], Where: new [name: 'alice']]]);
?. 'orm update rows=' & r2.User.rows;
var g2 = OrmGet(db, new [User: new [name: 'alice']]);
?. 'orm age now=' & g2.User[0].age;

var r3 = OrmDelete(db, new [User: new [name: 'bob']]);
?. 'orm delete rows=' & r3.User.rows;
var left = db.Execute('SELECT COUNT(*) AS c FROM "User"', false);
?. 'orm remaining=' & left[0].c;

var eac = db.ExecuteAndClose('SELECT 42 AS x', false);
?. 'eac=' & eac[0].x & ' closed=' & db.Closed();
