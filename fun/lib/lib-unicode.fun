// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-math.fun';

var Unicode = UnicodeClass();
class UnicodeClass()
  var apis = new [
    tobytes  : 'kernel32'.getapi('WideCharToMultiByte', 'iiripiii:i'),
    frombytes: 'kernel32'.getapi('MultiByteToWideChar', 'iiripi:i')
  ];

  var gb2312 = 936;
  var utf16  = 1200;
  var utf16b = 1201;
  var utf32  = 12000;
  var utf32b = 12001;
  var utf7   = 65000;
  var utf8   = 65001;

  var cps = new [
    gb2312: gb2312,
    utf16 : utf16,
    utf16b: utf16b,
    utf32 : utf32,
    utf32b: utf32b,
    utf7  : utf7,
    utf8  : utf8
  ];

  fun fromBytes(s, cp)
    var l = apis.frombytes(cp, 0, s, -1, 0, 0) * 2; //?. l;
    result = 0.toChar().x(l);
    var m = apis.frombytes(cp, 0, s, -1, result, l);
    result = result.substr(len: min(l, m*2));
  end fun;

  fun toBytes(s, cp)
    var l = apis.tobytes(cp, 0, s, -1, 0, 0, 0, 0); //?. l;
    result = 0.toChar().x(l);
    var m = apis.tobytes(cp, 0, s, -1, result, l, 0, 0);
    result = result.substr(len: min(l, m)).replace(/\x0++$/, '');
  end fun;

  fun utf8toGb2312(s)
    var ascii;
    if isUtf8(s, var ascii) and not ascii then
      result = fromBytes(s.toStr(), utf8);
      result = toBytes(result, gb2312);
      //result = result.replace(/\x0++$/, '');
    else
      result = s;
    end if;
  end fun;

  fun gb2312toUtf8(s)
    var ascii;
    if not isUtf8(s, var ascii) and not ascii then
      result = fromBytes(s.toStr(), gb2312);
      result = toBytes(result, utf8);
      //result = result.replace(/\x0++$/, '');
    else
      result = s;
    end if;
  end fun;
  var utf8toGbk = utf8toGb2312;
  var gbktoUtf8 = gb2312toUtf8;

  fun isUtf8(s, ascii)
    s = s.toStr();
    result = s.length() > 3 and s.substr(len: 3) = '\xef\xbb\xbf'.escape();
    ascii = not result;
    if not result then
      #/^([\x00-\x7F]|[\xC2-\xDF][\x80-\xBF]|\xE0[\xA0-\xBF][\x80-\xBF]|[\xE1-\xEC][\x80-\xBF]{2}|\xED[\x80-\x9F][\x80-\xBF]|[\xEE-\xEF][\x80-\xBF]{2}|\xF0[\x90-\xBF][\x80-\xBF]{2}|[\xF1-\xF3][\x80-\xBF]{3}|\xF4[\x80-\x8F][\x80-\xBF]{2})*$/
      #/^([\x00-\x7F]|([\xC2-\xDF]|\xE0[\xA0-\xBF]|\xED[\x80-\x9F]|(|[\xE1-\xEC]|[\xEE-\xEF]|\xF0[\x90-\xBF]|\xF4[\x80-\x8F]|[\xF1-\xF3][\x80-\xBF])[\x80-\xBF])[\x80-\xBF])*$/
      var m = s =~ /^(?:[\x00-\x7f]++|([\xc2-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf4][\x80-\xbf]{3})++)*+$/s;
      if m then
        result = true;
        ascii = m.@(1) = nil;
      else
        ascii = false;
      end if;
    end if;
  end fun;

  fun isGb2312(s, ascii)
    result = false;
    ascii  = false;
    s = s.toStr();
    var m = s =~ /^(?:[\x00-\x7f]++|([\xa1-\xf7][\xa1-\xfe])++)*+$/s;
    if m then
      result = true;
      ascii = m.@(1) = nil;
    end if;
  end fun;
end class;
