// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-xml.fun';
use 'lib-set.fun';

#*db
    schema       = [x: args, ...]
    quotes       = "%s"
    dot          = .
    ps           = [selectAutoId: ...]
    PrintSQL()
    dontPrintSQL = false
  args
    Schema
    Alias
    Name
    @Fields
     [Alias: [...], ...]
      Alias
      Name
      DataType
      IsPrimary
      IsAutoId
    @Parent
     [Parent_Name: [...], ...]
      Alias
      @Keys
       [Parent_Prop_Alias: This_Prop_Alias]
    @Children
     [Child_Name: [...], ...]
      Alias
      @Keys
       [Child_Prop_Alias: This_Prop_Alias]
#
class DObject(db, args)
  var @old$;          // 属性值表 - 未修改
  var props = new []; // 属性值表
  var isNew = true;
  var ToString = n -> props.@toJson(n);

  fun SaveOld()
    this.isNew = false;
    this.@old$ = this.props.@clone();
  end fun;

  //===============================================================================================
  // Relations
  //===============================================================================================
  var GetParent  (name, getKeys, DO) = this.GetRelation(name, this.args.@Parent, true, getKeys, var DO);
  var GetChildren(name, getKeys, DO) = this.GetRelation(name, this.args.@Children,  0, getKeys, var DO);
  fun GetRelation(name, relation, isParent, getKeys, DO)
    if DO = nil then
      DO = DObject;
    end if;
    var r = relation[name];
    var kvs = new [];
    for a: b in r.@Keys do
      kvs[a] = this.props[b];
    end do;
    if getKeys then
      result = kvs;
    else
      result = DO(db, db.schema[r.Alias]).Get(kvs, isParent);
    end if;
  end fun;

  fun NewChildren(name, DO)
    var kvs = GetChildren(name, true, var DO);
    result = DO(db, db.schema[args.@Children[name].Alias]);
    for k: v in kvs do
      result.props[k] = v;
    end do;
  end fun;

  //===============================================================================================
  // CRUD
  //===============================================================================================
  fun Save()
    this.CheckWritable?();
    if isNew then
      var vs = '';
      var fs = Fields(props, true, var vs);
      var sql = 'INSERT INTO %s\n\t(%s)\nVALUES\n\t(%s)\n'.escape().format(DQ(args.Name, true), fs.substr(2), vs.substr(2));
      var autoId = find(args.@Fields, e -> e.IsAutoId);
      var rsNext = false;
      if autoId <> nil and db.ps.selectAutoId <> nil then
        sql &= '; ' & db.ps.selectAutoId & '\n'.escape(); // todo(fixed): Insert 2 records once a time
        rsNext = true;
      end if;
      PrintSQL(sql);
      result = db.Execute(sql, rsNext); // get AutoId ?
      if rsNext and result then
        try
          props[autoId.Alias] = '' & result[0].autoId; // convert to string
        except
        end try;
      end if;
      SaveOld();
    else
      result = Update();
    end if;
  end fun;

  var GetByKey(kvs) = Get(kvs, true);
  fun Get(kvs, isPKey, set_quantifier, order) // DISTINCT, TOP ...
    var sql = this.BuildSqlPrefix?();
    sql &= 'SELECT %s%s%s%s\n'.escape().format(set_quantifier, Fields(args.@Fields).substr(2), this.GetFromClause(), Where(kvs, isPKey));
    if order then
      sql &= 'ORDER BY %s\n'.escape().format(Fields(order, isOrder: true).substr(2));
    end if;
    PrintSQL(sql);
    var rs = db.Execute(sql); // DObject and DObjectSet
    if isPKey then
      if rs.@count() <> 1 then
        raise 'Expected 1 record but %s record(s) found.'.format(rs.@count());
      end if;
      Read(this, rs[0]);
      result = this;
    else
      result = new [];
      for r in rs do
        var o = DObject(db, args);
        var k = Read(o, r);
        result[k] = o;
      end do;
    end if;

    fun Read(o, r)
      result = '';
      o.props = new [];
      for k: v in o.args.@Fields do
        var val = r[v.Name];
        try
          if '' & val <> '' then // null, Equal
            o.props[k] = val;
            if v.IsPrimary then
              result &= '@' & val;
            end if;
          end if;
        except
        end try;
      end do;
      o.SaveOld();
    end fun;
  end fun;

  fun Update(kvs, isPKey)
    this.CheckWritable?();
    var ss = '';
    var old = @old$ or [];
    for k: v in props do
      var f = args.@Fields[k]; next when not f or ('' & v = '' & old[k]) or kvs = nil and f.IsPrimary; // Equal ! Ignore Keys !
      ss &= ',\n\t%s = %s'.escape().format(DQ(f.Name), SQ(v, f.DataType));
    end do;
    var sql = 'UPDATE %s\nSET\n%s%s\n'.escape().format(DQ(args.Name, true), ss.substr(2), Where(kvs, isPKey));
    PrintSQL(sql);
    result = db.Execute(sql);
    if kvs = nil then
      SaveOld();
    end if;
  end fun;

  fun Delete(kvs, isPKey)
    this.CheckWritable?();
    var sql = 'DELETE FROM %s%s\n'.escape().format(DQ(args.Name, true), Where(kvs, isPKey));
    PrintSQL(sql);
    result = db.Execute(sql); // todo: Remove from owner list ?
  end fun;

  fun Where(kvs, isPKey)
    var ps = kvs or new [];
    if not ps then
      for k: v in (@old$ or []) do
        var f = args.@Fields[k]; next when not f;
        if f.IsPrimary then
          ps[k] = v;
        end if;
      end do;
    end if;

    if isPKey then
      for k: v in args.@Fields do
        if v.IsPrimary and ps[k] = nil then
          raise 'Primary key $k is missed.'.eval();
        end if;
      end do;
    end if;

    result = Condition(ps);
    if result <> '' then
      result = '\nWHERE%s'.escape().format(result.replace(/^\s*+/, ' '));
    end if;
  end fun;

  fun Condition(kvs, isOr, level, pf, args)
    args = args or this.args;
    var AND = 'AND';
    if isOr = '$OR' then
      AND = 'OR';
    end if;
    result = '';
    for k: v in kvs do
      var exp = '';
      if k =~ /^\$(OR|AND|NOT)$/i then
        exp = this.Condition(v, k, level + 1);
        result &= ' %s %s'.format(AND, exp).escape();
      else
        var m = k.match(/^\$(NOT\s*+)?(IN|EXISTS)/i);
        if m then
          var f = pf; next when not f;
          var OT = m.@(2).upper();
          OT = m.@(1) and m.@(1).upper().replace(/\s*+$/, ' ') & OT or OT;
          if v <> nil and v.@count() > 0 and v.$query <> nil then
            var subSql = this.BuildSubSelect(v.$query);
            exp = '%s %s%s (%s)'.format(DQ(f.Name), OT, '', subSql);
          else
            exp = '%s %s %s'.format(DQ(f.Name), OT, SQ(v, f.DataType, true));
          end if;
        else
          var f = args.@Fields[k]; next when not f;
          if v?.@count?() = 1 then
            exp = this.Condition(v, k, level, f).replace(/^\s*+\n/s, '').replace(/(?<=\n)/gs, '\t'.escape().x(level+1));
          else
            var re = /^([<!=>]++|(NOT\s++)?(LIKE|BETWEEN|IN))\s*+/i; // todo: Like ... Escape ..
            var EQ = '=';
            if 'NULL' = v or 'NOT NULL' = v then
              EQ = 'IS';
            elsif v =~ re then
              EQ = v.match(re).@(1).upper();
              v = v.replace(re, '');
            end if;
            exp = '%s %s %s'.format(DQ(f.Name), EQ, SQ(v, f.DataType, EQ =~ /IS|BETWEEN|IN/));
          end if;
        end if;
        result &= ' %s\n%s%s'.format(AND, '\t'.x(level + 1), exp).escape();
      end if;
    end do;
    result = result.replace(/^\s(AND|OR)\b/, '');
    if isOr in ['$OR', '$NOT'] then
      result = '(%s\n%s)'.format(result, '\t'.x(level)).escape();
    end if;
    if isOr = '$NOT' then
      result = 'NOT ' & result;
    end if;
  end fun;

  fun Fields(kvs, isInsert, vs, isOrder, isCreate)
    result = '';
    for k: v in kvs do
      var f = args.@Fields[k]; next when not f or isInsert and f.IsAutoId;
      result &= ', ' & DQ(f.Name);
      if isInsert then
        vs &= ', ' & SQ(v, f.DataType);
      elsif isOrder and v < 0 then
        result &= ' DESC';
      elsif isCreate then
        result &= '\t' & isCreate[f.DataType];
        if f.IsPrimary then
          //result &= ' PRIMARY KEY';
        end if;
      end if;
    end do;
  end fun;

  fun Create(dataTypes)
    dataTypes = dataTypes or ['SMALLINT', 'INT', 'INT', 'FLOAT', 'DOUBLE PRECISION', 'NUMERIC', 'SMALLINT', 'CHAR', 'DATE', 'CHAR', 'VARCHAR', 'BIT', 'BIT'];
    var sql = 'CREATE TABLE %s (\n\t%s\n)\n'.format(DQ(args.Name, true), Fields(args.@Fields, isCreate: dataTypes).substr(2).replace(/,\x20/g, ',\n\t')).escape();
    PrintSQL(sql);
    result = db.Execute(sql);
  end fun;

  //===============================================================================================
  // Utils
  //===============================================================================================
  fun DQ(s, isTable)
    result = '';
    if isTable and args.Schema <> '' then
      result = DQ(args.Schema) & db.dot;
    end if;
    result &= db.quotes.format(s);
  end fun;

  fun SQ(v, dt, dontSQ)
    if dontSQ or dt <= 6 then // todo: SQL Injection
      if v =~ %\b(Or|Union|Go|Into)\b|;|--|/\*|\n%i then
        raise 'SQL Injection!!!';
      elsif v.replace(/[^']++/g, '').length() mod 2 = 0 then
        result = v;
      else
        result = v.replace(/'/g, "''");
      end if;
    else
      result = "'%s'".format(v.replace(/^'(.*?)'$/, '$1').replace(/'/g, "''"));
    end if;
  end fun;

  fun PrintSQL(s)
    if db.PrintSQL <> nil then
      db.PrintSQL(s);
    elsif not db.dontPrintSQL then
      ?. s;
    end if;
  end fun;

  fun GetFromClause()
    return '\nFROM %s'.escape().format(DQ(args.Name, true));
  end fun;

  fun BuildSubSelect(queryDef)
    raise 'Subquery not supported in base DObject.';
  end fun;
end class;

//===============================================================================================
// Schema
//===============================================================================================
fun LoadSchema(s)
  var xml = XmlDocument();
  xml.load(s);
  var json = xml.toJson();
  json = json.$;
  var objs = find(json, e -> e.Name = 'DoTable');
  var flds = find(json, e -> e.Name = 'DoField');
  var rels = find(json, e -> e.Name = 'DoRelation');
  var rfds = find(json, e -> e.Name = 'DoRelationField');
  result = new [];
  for t in objs.$ do next when not t.IsEnabled;
    var o = new [];
    if t.SchemaName <> '' then
      o.Schema = t.SchemaName;
    end if;
    o.Alias  = t.Alias;
    o.Name   = t.Name;
    result[o.Alias] = o;

    var autoKey = nil;
    var keys = 0;
    o.@Fields = new [];
    var fs = filter(flds.$, e -> e.Table_Id = t.Id);
    for f in fs do next when not f.IsEnabled;
      var p = new [];
      p.Alias = f.Alias;
      p.Name  = f.Name;
      p.DataType  = f.DataType div 1;
      p.IsPrimary = f.IsPrimary;
      p.IsAutoId  = f.IsAutoIncrement; // IsNullable ...
      if p.IsPrimary then
        keys += 1;
      end if;
      if p.IsPrimary and p.IsAutoId then
        autoKey = p.Name;
      end if;
      o.@Fields[p.Alias] = p;
    end do;
    if keys = 1 and autoKey <> nil then
      o.@AutoKey = autoKey;
    end if;

    o.@Parent = new [];
    if rels and rels.$ then
      for r in filter(rels.$, e -> e.ChildTable_Id = t.Id) do next when not r.IsEnabled;
        var rf = new [];
        o.@Parent[r.ParentName] = rf;
        rf.Alias = find(objs.$, e -> e.Id = r.ParentTable_Id).Alias;
        rf.@Keys = new [];
        for f in filter(rfds.$, e -> e.Relation_Id = r.Id) do
           rf.@Keys[find(flds.$, e -> e.Id = f.ParentField_Id).Alias] = find(flds.$, e -> e.Id = f.ChildField_Id).Alias;
        end do;
      end do;
    end if;

    o.@Children = new [];
    if rels and rels.$ then
      for r in filter(rels.$, e -> e.ParentTable_Id = t.Id) do next when not r.IsEnabled;
        var rf = new [];
        o.@Children[r.ChildName] = rf;
        rf.Alias = find(objs.$, e -> e.Id = r.ChildTable_Id).Alias;
        rf.@Keys = new [];
        for f in filter(rfds.$, e -> e.Relation_Id = r.Id) do
           rf.@Keys[find(flds.$, e -> e.Id = f.ChildField_Id).Alias] = find(flds.$, e -> e.Id = f.ParentField_Id).Alias;
        end do;
      end do;
    end if;
  end do;
end fun;

class NewSchema(db)
  var New(name) = DObject(db, db.schema[name]);
end class;