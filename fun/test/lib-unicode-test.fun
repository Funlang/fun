// lib-unicode on Linux: pure-Fun GBK (CP936) <-> UTF-8 (no kernel32).
// Host-dependent (Linux backend; Windows uses kernel32 instead).
use 'fun/lib/lib-utils.fun';
use 'fun/lib/lib-unicode-lnx.fun';

fun g2u(h)
  result = str2hex(Unicode.gb2312toUtf8(hex2str(h)));
end fun;
fun u2g(h)
  result = str2hex(Unicode.utf8toGb2312(hex2str(h)));
end fun;

// gb2312 -> utf8
?. g2u('d6d0cec4');                       // 中文
?. g2u('b2e2cad4d6d0cec4');               // 测试中文
?. g2u('e946');                           // 镕 (GBK extension, not in GB2312)
?. g2u('a3aca1a3a3a1');                   // ，。！
?. g2u('d6d0cec4616263b2e2cad4');         // 中文abc测试

// utf8 -> gb2312
?. u2g('e4b8ade69687');
?. u2g('e6b58be8af95e4b8ade69687');
?. u2g('e99595');
?. u2g('efbc8ce38082efbc81');
?. u2g('e4b8ade69687616263e6b58be8af95');

// ascii passes through both ways
?. g2u('61626358595a313233');
?. u2g('61626358595a313233');

// alias
?. str2hex(Unicode.utf8toGbk(hex2str('e4b8ade69687')));

// charset sniffing (pure, same on both platforms)
var ascii;
?. Unicode.isUtf8(hex2str('e4b8ade69687'), var ascii);
?. ascii;
?. Unicode.isGb2312(hex2str('d6d0cec4'), var ascii);
?. ascii;
