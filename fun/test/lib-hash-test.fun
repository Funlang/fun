// str.md5() / str.sha1() builtins against published test vectors.
//
// Host-dependent: these builtins are registered under -dMD5, which the Linux
// build now defines (see make-linux-x86_64.sh). On Linux src/libmd5.inc uses a
// portable branch (FPC's bundled md5/sha1 units) instead of advapi32.dll.
?. ''.md5();
?. 'abc'.md5();
?. 'The quick brown fox jumps over the lazy dog'.md5();
?. 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'.md5();
?. ''.sha1();
?. 'abc'.sha1();
?. 'The quick brown fox jumps over the lazy dog'.sha1();
?. 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'.sha1();
