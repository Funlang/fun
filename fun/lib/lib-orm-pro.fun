// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-orm.fun';

fun OrmGet(db, args)
  result = new [];
  for k: v in args do
    var s = db.schema[k];
    if s <> nil then
      var DO = DObject(db, s);
      var dl = DO.Get(v, set_quantifier: v.$Set_quantifier, order: v.$Order);
      var nl = new [];
      result[k] = nl;
      for d in dl do
        nl.@add(d.props);
      end do;
    else
      raise 'DObject $k not found.'.eval();
    end if;
  end do;
end fun;

var OrmSave(db, args) = OrmModify(db, args, (db, oschema, ovalue, ret) {
  for o in ovalue do
    var DO = DObject(db, oschema);
    DO.props = o;//.@clone();
    var r = DO.Save();
    if '' & r[0].autoId <> '' then
      ret.autoId = r[0].autoId;
    end if;
    // 'nil += n' stays nil in Fun: seed the counter, otherwise the affected-row
    // count is silently dropped (it used to be nil in every orm-pro result).
    ret.rows = (ret.rows or 0) + (r[0].rows or 0);
  end do;
});

var OrmUpdate(db, args) = OrmModify(db, args, (db, oschema, ovalue, ret) {
  var DO = DObject(db, oschema);
  DO.props = ovalue.Set;
  var r = DO.Update(ovalue.Where);
  ret.rows = (ret.rows or 0) + (r[0].rows or 0);
});

var OrmDelete(db, args) = OrmModify(db, args, (db, oschema, ovalue, ret) {
  var DO = DObject(db, oschema);
  var r = DO.Delete(ovalue);
  ret.rows = (ret.rows or 0) + (r[0].rows or 0);
});

var OrmCreate(db, args) = OrmModify(db, args, (db, oschema, ovalue, ret) {
  var DO = DObject(db, oschema);
  var r = DO.Create();
  ret.rows = (ret.rows or 0) + (r[0].rows or 0);
});

fun OrmModify(db, args, f)
  result = new [];
  db.Begin();
  try
    for k: v in args do
      result[k] = new [];
      var s = db.schema[k];
      if s <> nil then
        f(db, s, v, result[k]);
      else
        raise 'DObject $k not found.'.eval();
      end if;
    end do;

    db.Commit();
  except
    db.Rollback();
    raise @;
  end try;
end fun;
