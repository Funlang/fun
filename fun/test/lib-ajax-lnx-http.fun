// lib-ajax-lnx over a live HTTP fixture (started by run-ajax-lnx.sh).
use 'fun/lib/lib-ajax-lnx.fun';
use 'fun/lib/lib-utils.fun';

var B = 'http://127.0.0.1:18731';
var a = Ajax();

a.go(new [url: B & '/hello']);
?. 'GET=' & a.code & ' ' & a.message & ' ' & a.html & ' ct=' & a.headers['content-type'] & ' xt=' & a.headers['x-test'];

a.go(new [url: B & '/missing']);
?. '404=' & a.code & ' ' & a.message & ' ' & a.html;

a.go(new [url: B & '/redir']);
?. 'redir=' & a.code & ' ' & a.html;

var p = a.go(new [url: B & '/echo', body: 'payload', method: 'POST', userAgent: 'fun-client']);
?. 'POST=' & a.code & ' ' & p;

a.go(new [url: B & '/hdr', headers: new ['X-Custom': 'abc']]);
?. 'HDR=' & a.code & ' ' & a.html;

a.go(new [url: B & '/file.bin']);
?. 'BIN=' & str2hex(a.html) & ' ct=' & a.headers['content-type'];
