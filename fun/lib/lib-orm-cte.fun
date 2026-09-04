// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-orm.fun';

class CteObject = DObject()
  fun BuildColumns(kvs, flag) // 0-Fields, 1-Select, 2-Order
    kvs = kvs or args.@Fields;
    var s = '';
    for k: v in kvs do
      if s <> '' then s &= ', '; end if;
      s &= flag = 2 and k or flag = 1 and v or v.name;
      if flag = 2 and v < 0 then ord &= ' DESC'; end if;
    end do;
    if flag = 0 and s <> '' then s = '(' & s & ')'; end if;
    return s;
  end fun;

  fun BuildQuerySQL(q)
    if q = nil then raise 'BuildQuerySQL: query definition is nil'; end if;
    var sql = 'SELECT ';
    if q.distinct then sql &= 'DISTINCT '; end if;
    if q.limit then
      var lmt = q.limit;
      if ('' & lmt) !~ /^-?\d++$/ then
        raise 'BuildQuerySQL: invalid limit value'.eval();
      end if;
      sql &= 'TOP ' & lmt & ' ';
    end if;
    sql &= q.select and BuildColumns(q.select, 1) or '*';

    var fromStr = '';
    if q.from.length() > 0 then
      if db.schema[q.from] <> nil then
        fromStr = DQ(db.schema[q.from].Name, true) & ' AS ' & q.from;
      else
        var tf = '' & q.from;
        if tf !~ /^[A-Za-z_][A-Za-z0-9_]*+$/ then
          raise 'BuildQuerySQL: invalid from identifier'.eval();
        end if;
        fromStr = tf;
      end if;
    elsif q.from.$cte then
      var tc = '' & q.from.$cte;
      if tc !~ /^[A-Za-z_][A-Za-z0-9_]*+$/ then
        raise 'BuildQuerySQL: invalid cte identifier'.eval();
      end if;
      fromStr = tc;
    else
      raise 'BuildQuerySQL: unsupported from type';
    end if;
    if q.cte <> nil then
      fromStr &= ', ' & q.cte;
    end if;
    sql &= '\nFROM ' & fromStr;

    if q.where and q.mainObject then
      var curArgs = db.schema[q.mainObject];
      if curArgs = nil then
        raise 'BuildQuerySQL: mainObject "' & q.mainObject & '" not found in schema';
      end if;
      var whereClause = Condition(q.where, nil, 0, args: curArgs);
      if whereClause <> '' then
        sql &= '\nWHERE' & whereClause.replace(/^\s*+/, ' ');
      end if;
    end if;

    if q.order then
      sql &= '\nORDER BY ' & BuildColumns(q.order, 2);
    end if;
    return sql.escape();
  end fun;

  fun BuildSqlPrefix()
    var kw = 'WITH';
    if args.isRecursive then kw = 'WITH RECURSIVE'; end if;
    var cols = BuildColumns();
    var anchorSql = BuildQuerySQL(args.anchor).replace(/(?<=\n)/gs, '\t'.escape());
    var recDef = args.recursive.@clone();
    recDef.cte = args.name;
    var recSql = BuildQuerySQL(recDef).replace(/(?<=\n)/gs, '\t'.escape());
    result = '%s %s %s AS (\n\t%s\n\tUNION ALL\n\t%s\n)\n'.format(kw, args.name, cols, anchorSql, recSql).escape();
  end fun;

  fun GetFromClause()
    return '\nFROM %s\n'.escape().format(args.name);
  end fun;

  fun CheckWritable()
    raise 'CteObject is read-only.';
  end fun;

  fun BuildSubSelect(queryDef)
    return this.BuildQuerySQL(queryDef);
  end fun;
end class;

class QueryDObject = DObject()
  fun BuildSubSelect(queryDef)
    return CteObject.BuildQuerySQL(queryDef, db);
  end fun;
end class;
