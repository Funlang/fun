// End-to-end integration of the Linux ports: lib-crypt (hash + AES) ->
// lib-zlib (compress) -> lib-os-lnx (temp file) -> read back -> decompress ->
// decrypt, plus lib-cmdline-lnx host facts. The SHA-256 value is the published
// digest of 100 'A' bytes; the AES-256-CBC ciphertext length is the modulus.
use 'fun/lib/lib-zlib.fun';
use 'fun/lib/lib-crypt-lnx.fun';
use 'fun/lib/lib-cmdline-lnx.fun';
use 'fun/lib/lib-os-lnx.fun';

var payload = 'A'.x(100);
var key = '0123456789abcdef0123456789abcdef';   // AES-256
var iv  = 'abcdef0123456789';

// lib-crypt: SHA-256 and AES-256-CBC (zero padding)
?. Crypt(payload, CALG_Sha256) = 'd82c6aa133a0fc25b087f46ad7ed2a3042772e612e015571e61753ff55ba6da8';
var enc = AES(payload, key, false, new [mode: CRYPT_MODE_CBC, iv: iv, padding: ZERO_PADDING]);
?. enc.length() = 112;

// lib-zlib: compress the ciphertext
var comp = compress(enc);
?. comp.length() > 0;

// lib-os-lnx: temp path + file write/read
var f = GetTempPath('e2e-' & GetPId() & '.z');
f.save(comp);
?. f.size() > 0;

// read back -> decompress -> decrypt
var back = decompress(f.load(), enc.length());
?. back = enc;
var dec = AES(back, key, true, new [mode: CRYPT_MODE_CBC, iv: iv, padding: ZERO_PADDING]);
?. dec.substr(0, payload.length()) = payload;
?. dec.substr(payload.length()).length() = 12;   // zero-pad to the block

// lib-cmdline-lnx host facts (run with no extra arguments)
?. CmdLineParams.@exe.substr(0, 1) = '/';
?. CmdLineParams.options.@count() = 0;

f.move();
?. f.size() = 0;
