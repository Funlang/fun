// lib-zlib on Linux: deflate/inflate and the simple compress/uncompress API.
// Deterministic output (lengths and equality), snap-friendly.
use 'fun/lib/lib-zlib.fun';

?. zlib <> nil;

var s = 'hello hello hello world world world 1234567890 abcabcabc ' .x(40);

var c = compress(s);
?. c.length() < s.length();
?. decompress(c, s.length()) = s;

var c2 = compress(s, true);
?. c2.length() < c.length();

var raw = deflate(s, 9);
?. raw.length() > 0;
?. inflate(raw, new []) = s;

// empty input round trips (deflate must still emit the 2-byte end-of-stream)
?. decompress(compress(''), 0) = '';
?. inflate(deflate('', 9), new []) = '';

// incompressible-ish data still round trips (compressBound sizing)
var rnd = '';
for i = 0 to 255 do rnd &= i.toChar(); end do;
var cr = compress(rnd);
?. decompress(cr, rnd.length()) = rnd;
