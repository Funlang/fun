// Regression: a regex replace must not mutate its subject.
//
// On the FPC/non-Unicode build PCREString = AnsiString = fun.str, so the
// subject passed to CRegex.replace aliases the caller's string and
// CPcre.Replace's raw pointer writes leaked into it; on a Unicode build
// (Delphi) the implicit UnicodeString -> UTF8String conversion made a fresh
// temporary, hiding it. See known-issues H-11 / port-decisions D14.
// Host-independent output (the same assertions should hold on Windows/Unicode).
fun show(k, v)
  ?. k & '=[' & v & ']';
end fun;

var a = 'abcd 1234 efgh';
var b = a.replace(/\d++/g, '0');        // shorter  -> was the leaky case
show('a', a);
show('b', b);
show('a.subpos1234', a.subpos('1234'));

var c = 'hello world';
var d = c.replace(/world/, 'there');    // equal length
show('c', c);
show('d', d);

var e = 'aaa';
var f = e.replace(/a/, 'bb');           // longer
show('e', e);
show('f', f);

var g = 'x 1 y 22 z';
var h = g.replace(/\d++/g, m->'<' & m.@@() & '>');  // callback
show('g', g);
show('h', h);

var i = 'no digits here';
var j = i.replace(/\d++/g, '0');        // no match at all
show('i', i);
show('j', j);

show('ok', 'ok');
