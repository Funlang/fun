// lib-ajax-lnx: deterministic checks (no network dependency).
// file:// fixtures cover the transfer plumbing; CorrectURL and the transport
// error path are pure/deterministic. Live HTTP is run-ajax-lnx.sh (snap mode).
use 'fun/lib/lib-ajax-lnx.fun';

// NOTE: `f.save(content)` - the RECEIVER is the file name and the argument is
// the content (see lib-file's built-in docs). A path literal as receiver is a
// silent no-op, so bind the path to a variable first.
var fixture = '/tmp/fun-ajax-lnx-fixture.txt';
var payload = 'hello from fixture';
fixture.save(payload);

var a = Ajax();

var url = 'file://' & fixture;
var r = a.go(new [url: url]);
?. 'file rc=' & a.rc & ' code=' & a.code;
?. 'file body=' & r;
?. 'file html=' & a.html;

var out = '/tmp/fun-ajax-lnx-out.txt';
a.go(new [url: url, saveas: out]);
?. 'saveas=' & out.load();

// CorrectURL (pure): scheme passthrough, absolute path, bare host, relative
?. 'abs='    & CorrectURL('x/y', 'http://h/a/b.html');
?. 'root='   & CorrectURL('/z',  'http://h/a/b.html');
?. 'scheme=' & CorrectURL('https://q/1', '');
?. 'bare='   & CorrectURL('example.com', '');
?. 'dir='    & CorrectURL('c', 'http://h/a/');

// transport error: nothing listens on 8729
var bad = 'http://127.0.0.1:8729/none';
a.go(new [url: bad]);
?. 'err rc=' & a.rc & ' msg=' & a.message & ' html=' & (a.html or 'nil');

// missing local file
var nofile = 'file:///no/such/fun-ajax-fixture';
a.go(new [url: nofile]);
?. 'nofile rc=' & a.rc;

// repeat: guards the write/header callback lifetime (a freed closure would
// crash or corrupt on the 2nd transfer) and handle cleanup.
var ok = 0;
for i = 1 to 100 do
  var r2 = a.go(new [url: url]);
  if a.rc = 0 and r2 = payload then ok += 1; end if;
end do;
?. 'repeat ok=' & ok;
