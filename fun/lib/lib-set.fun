// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

########################################
# lib-set
########################################
#   built-in (4)
########################################
#     s.@count (     )
#               'ptr'   # return pointer
#               n or -n # resize to n or count-n
#     s.@each  (fun, reverse = false) # fun (val) or (val, key)
#     s.@add   (v1, v2, ...)
#     s.@clone ()
########################################

var pathSet(set, path, value) = locate(set, path, value, 1);
var pathInc(set, path, value) = locate(set, path, value, 2);
fun locate(set, path, value, mode) // mode: 0-get, 1-set, 2-inc
  var lp = nil;
  for p in path do
    if lp <> nil then
      if set[lp] = nil then
        set[lp] = new [];
      end if;
      set = set[lp];
    end if;
    lp = p;
  end do;
  result = set[lp];
  if mode = 1 then
    set[lp] = value;
  elsif mode = 2 then
    set[lp] += value;
  end if;
end fun;

fun filter(s, f, n)
  var ret = n or new [];
  s.@each((v, k){
    if f(var v, k) then
      if k <> nil then
        ret[k] = v;
      else
        ret.@add(v);
      end if;
    end if;
  });
  result = ret;
end fun;

fun find(s, f)
  result = nil;
  for v in s do
    if f(v) then
      return v;
    end if;
  end do;
end fun;

fun compose(args, a)
  args.@each((f){
    a = f(a);
  }, true);
  return a;
end fun;

fun map(fn, list)
  var set = new [];
  list.@each( v -> set.@add(fn(v)) );
  result = set;
end fun;

fun fromPairs(list)
  var set = new [];
  list.@each( (v){
    set[v[0]] = v[1];
  });
  result = set;
end fun;

fun reducePairs(p, a)
  a = a or new [];
  for i = 0 to p.@count() -1 step 2 do
    a[p[i]] = p[i+1];
  end do;
  result = a;
end fun;

fun mapReduce(map, reduce, a)
  var ret;
  a.@each( v -> reduce(map(v), var ret) );
  result = ret;
end fun;
var mapReduceEx(map, reduce, preMap, a) = mapReduce(map, reduce, preMap(a));

fun formats(str, set)
  result = str.replace(/\{(\w++)\}/g, (m){
    result = formats(set[m.@(1)], set);
  });
end fun;

var mergeJson = mergeSet;
fun mergeSet(src, dst, isInc)
  for k: v in src do
    if k = nil then
      dst.@add(v);
    elsif dst[k] = nil then
      dst[k] = v;
    else
      try
        if v.@count() > 0 or dst[k].@count() > 0 then
          mergeSet(v, dst[k], isInc);
        else
          setRet();
        end if;
      except //?. @;
        setRet();
      end try;
    end if;

    fun setRet()
      try
        if isInc then
          dst[k] += v * 1;
        else
          dst[k]  = v;
        end if;
      except
        dst[k]  = v;
      end try;
    end fun;
  end do;
end fun;

# result = s2 - s1
fun diffSet(s1, s2, ret)
  ret = ret or new [];
  result = ret;

  for k: v in s2 do
    if s1[k] = nil then
      setRet();
    else
      try
        if s2[k].@count() >= 0 and s1[k].@count() >= 0 then
          var d = diffSet(s1[k], s2[k]);
          if d then
            ret[k] = d;
          end if;
        else
          setRet();
        end if;
      except //?. @;
        setRet();
      end try;
    end if;

    fun setRet()
      if v <> s1[k] then
        if k = nil then
          ret.@add(v);
        else
          ret[k] = v;
        end if;
      end if;
    end fun;
  end do;
end fun;
