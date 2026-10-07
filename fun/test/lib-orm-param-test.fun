
########################################
# ORM parameterization smoke test (no DB required)
########################################
# Drives a DObject (mock db + hand-built schema) through Save/Get/Update/Delete.
# PrintSQL prints the final SQL plus the params JSON, so you can check:
#   1) no business value leaks into the SQL text (everything goes through '?');
#   2) both operator formats (legacy string / structured {op,value}) collapse to
#      the operator whitelist + params;
#   3) unknown fields / operators raise.
# Run (Windows): fun.exe -fun:fun\test\lib-orm-param-test.fun
########################################

use '../lib/lib-orm.fun';

// --- mock db: only collects/prints, never connects ---
var mydb = new [];
mydb.quotes = '"%s"';
mydb.dot = '.';
mydb.ps = new [selectAutoId: 'SELECT SCOPE_IDENTITY() AS autoId'];
mydb.Execute = (sql, rsNext, stream, from, top, tick, ps){
  result = new [];
  result.@add(new [rows: 0, autoId: 100]);
};

// --- hand-built schema (same shape as LoadSchema output) ---
fun F(alias, name, dt, isP, isAuto)
  result = new [Alias: alias, Name: name, DataType: dt, IsPrimary: isP, IsAutoId: isAuto];
end fun;

var targs = new [
  Alias: 'User',
  Name: 'User',
  Schema: 'dbo',
  @Fields: new [
    id:     F('id',     'id',     1, 1, 1),   // int PK auto
    name:   F('name',   'name',   9, 0, 0),   // varchar
    age:    F('age',    'age',    1, 0, 0),   // int
    active: F('active', 'active', 6, 0, 0),   // bit
    note:   F('note',   'note',  10, 0, 0)    // memo
  ]
];

fun NewDO()
  result = DObject(mydb, targs);
end fun;

var ln = '----------------------------------------';

?. ln;
?. '1) Save (INSERT values parameterized)';
var d1 = NewDO();
d1.props = new [name: "O'Brien", age: 30, active: 1, note: "hello 'quoted'"];
d1.Save();
d1 = nil;

?. ln;
?. '2) Get plain equality + single-value operators (legacy string)';
var d2 = NewDO();
d2.Get(new [age: '>18']);
d2.Get(new [age: '>=18']);
d2.Get(new [age: '<65']);
d2.Get(new [age: '18']);
d2 = nil;

?. ln;
?. '3) Get structured format B {op,value}';
var d3 = NewDO();
d3.Get(new [age: new [op: '>=', value: 18]]);
d3.Get(new [name: new [op: 'LIKE', value: 'A%']]);
d3.Get(new [active: new [op: 'IS NULL']]);
d3 = nil;

?. ln;
?. '4) Get BETWEEN / IN (both formats)';
var d4 = NewDO();
d4.Get(new [age: 'BETWEEN 18 AND 65']);
d4.Get(new [age: new [op: 'BETWEEN', value: [18, 65]]]);
d4.Get(new [age: 'IN (18, 30, 65)']);
d4.Get(new [age: new [op: 'IN', value: [18, 30, 65]]]);
d4 = nil;

?. ln;
?. '5) Update SET + WHERE parameterized';
var d5 = NewDO();
d5.props = new [age: 31];
d5.Update(new [name: "O'Brien"]);
d5 = nil;

?. ln;
?. '6) Delete WHERE parameterized';
var d6 = NewDO();
d6.Delete(new [id: 7]);
d6 = nil;

?. ln;
?. '7) Injection samples: values only go to params, never into SQL';
var d7 = NewDO();
d7.Get(new [name: "' OR 1=1--"]);
d7.Get(new [age: '1 AND (SELECT COUNT(*) FROM User)>0']);
d7 = nil;

?. ln;
?. '8) Negative: unknown field / unknown operator should raise';
var d8 = NewDO();
try
  d8.Get(new [nope: 1]);
  ?. '!! did not raise (unknown field)';
except
  ?. '  raised OK (unknown field): ' & '$@'.eval();
end try;
d8 = nil;

// A value with no operator prefix (e.g. 'HELLO 5') is treated, backward-compatibly,
// as a literal '=' value and bound safely (no raise). Only operator-prefixed values
// that are outside the whitelist raise.
var d8a = NewDO();
try
  d8a.Get(new [age: '! 5']);   // '!' is an operator prefix but not whitelisted
  ?. '!! did not raise (unknown operator legacy)';
except
  ?. '  raised OK (unknown operator legacy): ' & '$@'.eval();
end try;
d8a = nil;
var d8b = NewDO();
try
  d8b.Get(new [age: new [op: 'FOO', value: 1]]);  // structured unknown operator
  ?. '!! did not raise (unknown operator format B)';
except
  ?. '  raised OK (unknown operator format B): ' & '$@'.eval();
end try;
d8b = nil;

?. ln;
?. 'done';
