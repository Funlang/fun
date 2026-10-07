// lib-bnf: the dup:0 (auto-rename) path must produce UNIQUE group names.
//
// Fun's `nil += 1` stays nil, so lib-bnf's `count[n] += 1` never counted past
// the first hit; the `_k` renaming never ran and every dup:0 pattern still
// contained duplicate (?<name>) groups. PCRE then refused to compile it
// ("two named subpatterns have the same name"), which is what made lib-fd fail.
//
// The grammar loaded here (fd.bnf.fd) references some rules many times, so it
// is a good trap for that bug.
use 'fun/lib/lib-bnf.fun';
use ':../lib/fd.bnf.fd' as rules;
rules = rules.getJson(fd: true);

var re = CBNF(rules, dup: 0).regex;
var m  = re.match(/\x28\x3f<(\w++)>/g);
?. m.@count() > 0;                       // the pattern does define groups

var seen = new [];
var dups = new [];
for i = 0 to m.@count() - 1 do
  var t = m[i];
  var n = t.substr(3, t.length() - 4);
  if seen[n] = nil then
    seen[n] = 1;
  else
    dups.@add(n);
  end if;
end do;
?. dups.@count();                        // 0 duplicate names expected
?. 'dup:0 compiles: ' & (re.toRegex('gx').match('x') != nil or true);

// dup:1 keeps the (?J) prefix and the original names
var re2 = CBNF(rules, dup: 1).regex;
?. re2.substr(0, 4);
?. re2.match(/\x28\x3f<(\w++)>/g).@count() > 0;
