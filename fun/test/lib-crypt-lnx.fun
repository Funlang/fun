// lib-crypt-lnx on Linux (OpenSSL libcrypto): hash vectors, AES-CBC and RSA.
// The SHA/MD5 digests are standard published vectors; the AES-CBC ciphertext
// matches `openssl enc -aes-128-cbc` with the same key/iv (no padding); the RSA
// round trip uses an embedded throwaway 1024-bit test key (PKCS#1 v1.5).
use 'fun/lib/lib-crypt-lnx.fun';

?. Crypt('abc', CALG_MD5);
?. Crypt('abc', CALG_Sha1);
?. Crypt('abc', CALG_Sha256);
?. Crypt('abc', CALG_Sha384);
?. Crypt('abc', CALG_Sha512);

// CryptoAPI PLAINTEXTKEYBLOB for AES-128 with key '0123456789abcdef'
var blob = '\x08\x02\x00\x00\x0e\x66\x00\x00\x10\x00\x00\x00'.escape() & '0123456789abcdef';
var msg = 'The quick brown fox jumps over the lazy dog.';

var enc = AES(msg, blob, false, new [mode: CRYPT_MODE_CBC, iv: '0123456789abcdef', padding: ZERO_PADDING]);
?. str2hex(enc);
var dec = AES(enc, blob, true, new [mode: CRYPT_MODE_CBC, iv: '0123456789abcdef', padding: ZERO_PADDING]);
?. dec = msg & 0.toChar().x(4);

// raw key + PKCS7 default round trip
var e2 = AES(msg, '0123456789abcdef', false, nil);
?. AES(e2, '0123456789abcdef', true, nil) = msg;

// no state leaks between calls with and without options
?. AES(msg, '0123456789abcdef', false, nil) = e2;

?. RandomBytes(16).length();
?. RandomBytes(16) = RandomBytes(16);

// RSA (PKCS#1 v1.5): encrypt with the public key, decrypt with the private one.
var rsapriv = '-----BEGIN RSA PRIVATE KEY-----\nMIICXAIBAAKBgQDhErXgL5224Kq1iCB1Lgx7r68TB9Mnvej5cIviuNI9GuiTii8O\n6OWnOooBLKdaQPPyEV8fg2TeT72cR6r2o1HC/X2DG33si5tRut9ZAVqMHpI/iOmj\nc8eOJFxgXaURv3b85g187ZRBXlVzNjr20g1HpaIe0W3CIouVoHc9NQ23ywIDAQAB\nAoGAJ2iSRd2wfLvbyAs8u6fDcciyG9/r3fKHn11QcPMxhJd4j5TLZo3q4BwE2+3I\no6npzMGz6R2lhLNrnLiDu8me3/RTg1uJXDcCagYmpWrtsbySkiWfjGSm62Ws40oD\nHm5cz2DlekNA53jdWfKy51qbUlb4DwdW0nEQXEXeaLlt9BkCQQD1vAY3oHfVRiNY\nAFg7POfPIXJmhdFdy/YnhpIoxCmgqeogyjyo2v5Mtt5iZCR1tK30GwVvLWHIH1Bl\nyxbKIZcNAkEA6nm5xXD+SS5oIe+WqF/5nYnzQbgVMB9VC9fQatutKxDa3q0gtOns\nwlBHl2JSLpjJHeAdFAnEl3zzSCHRmd5UNwJBAMm2AdR/oF4tKK3/+m0F3bKk3edS\nST4ZQoHHcQqNmy4Ky+kGmSxyNvR516okUdlc6r3JwHg2ZGGFctVcE+TwFbECQA/c\nNf2t+/VVR0PsYeN3wnmuiB7M5doAdI89hOKFg3wjQrrHOSwjmpk2NvF9fBOc0BXO\nQAlH891PXWFmsDfZOxcCQGJawMr4anyWfFFYgywUuvWR7L12VHqwEWdDYtOI6+6v\n8QOTjSZOWSEeeQ1wwJ2/jFJYvcsknaZRBrLijdMvR4w=\n-----END RSA PRIVATE KEY-----\n'.escape();
var rsapub  = '-----BEGIN PUBLIC KEY-----\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDhErXgL5224Kq1iCB1Lgx7r68T\nB9Mnvej5cIviuNI9GuiTii8O6OWnOooBLKdaQPPyEV8fg2TeT72cR6r2o1HC/X2D\nG33si5tRut9ZAVqMHpI/iOmjc8eOJFxgXaURv3b85g187ZRBXlVzNjr20g1HpaIe\n0W3CIouVoHc9NQ23ywIDAQAB\n-----END PUBLIC KEY-----\n'.escape();
var ct = RSA_PEM('rsa round trip', rsapub, false);
?. ct.length() = 128;
?. RSA_PEM(ct, rsapriv, true) = 'rsa round trip';
?. RSA_PEM(RSA_PEM('x', rsapriv, false), rsapriv, true) = 'x';

// AES-256-CBC (raw 32-byte key) matches `openssl enc -aes-256-cbc -nopad`.
var k256 = '0123456789abcdef0123456789abcdef';
var e256 = AES(msg, k256, false, new [mode: CRYPT_MODE_CBC, iv: '0123456789abcdef', padding: ZERO_PADDING]);
?. str2hex(e256);
?. AES(e256, k256, true, new [mode: CRYPT_MODE_CBC, iv: '0123456789abcdef', padding: ZERO_PADDING]) = msg & 0.toChar().x(4);

// AES-192-CBC (raw 24-byte key) matches `openssl enc -aes-192-cbc -nopad`.
var k192 = '0123456789abcdef01234567';
var e192 = AES(msg, k192, false, new [mode: CRYPT_MODE_CBC, iv: '0123456789abcdef', padding: ZERO_PADDING]);
?. str2hex(e192);
?. AES(e192, k192, true, new [mode: CRYPT_MODE_CBC, iv: '0123456789abcdef', padding: ZERO_PADDING]) = msg & 0.toChar().x(4);

// ECB round trip (no iv)
var eecb = AES(msg & 0.toChar().x(4), k256, false, new [mode: CRYPT_MODE_ECB, padding: ZERO_PADDING]);
?. AES(eecb, k256, true, new [mode: CRYPT_MODE_ECB, padding: ZERO_PADDING]) = msg & 0.toChar().x(4);

