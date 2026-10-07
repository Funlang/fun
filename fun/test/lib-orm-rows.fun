// lib-orm-pro: the affected-row counter must actually accumulate.
//
// OrmModify hands each callback an empty `new []` as `ret`; the callbacks do
// `ret.rows += r[0].rows`. Fun's `nil += n` stays nil, so before the fix the
// counter was silently dropped and callers got nil instead of a number.
// Uses the same mock db style as fun/test/lib-orm-param-test.fun (no real DB).
use '../lib/lib-orm-pro.fun';

var MOCK_ROWS = 7;

var mydb = new [];
mydb.quotes = '"%s"';
mydb.dot = '.';
mydb.ps = new [selectAutoId: 'SELECT SCOPE_IDENTITY() AS autoId'];
mydb.Begin    = (){};
mydb.Commit   = (){};
mydb.Rollback = (){};
mydb.Execute = (sql, rsNext, stream, from, top, tick, ps){
  result = new [];
  result.@add(new [rows: MOCK_ROWS, autoId: 100]);
};

fun F(alias, name, dt, isP, isAuto)
  result = new [Alias: alias, Name: name, DataType: dt, IsPrimary: isP, IsAutoId: isAuto];
end fun;

var targs = new [
  Alias: 'User',
  Name: 'User',
  Schema: 'dbo',
  @Fields: new [
    id:   F('id',   'id',   1, 1, 1),
    name: F('name', 'name', 9, 0, 0),
    age:  F('age',  'age',  1, 0, 0)
  ]
];
mydb.schema = new [User: targs];

?. OrmUpdate(mydb, new [User: new [Set: new [age: 31], Where: new [id: 1]]]).User.rows;
?. OrmDelete(mydb, new [User: new [id: 1]]).User.rows;
?. OrmCreate(mydb, new [User: new []]).User.rows;
?. OrmSave(mydb,   new [User: new [[name: 'x', age: 20]]]).User.rows;

// an existing counter must still accumulate (not be reset)
?. OrmUpdate(mydb, new [User: new [Set: new [age: 1], Where: new [id: 1]]]).User.rows
   = MOCK_ROWS;
