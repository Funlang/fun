// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

// lib-unicode base: the platform-independent half.
//
// UnicodeBase holds the code-page constants plus everything that needs no OS
// charset API - the charset sniffers (isUtf8 / isGb2312) and the
// utf8toGb2312 / gb2312toUtf8 orchestration.
//
// fromBytes / toBytes are the only platform-specific parts and are overridden
// by the two backends:
//   lib-unicode.fun      - Windows, kernel32 WideCharToMultiByte family
//   lib-unicode-lnx.fun  - Linux, pure-Fun GBK(CP936) table
//
// Note: the base calls `this.fromBytes` / `this.toBytes` on purpose - an
// unqualified call would bind to the (abstract) method declared here instead of
// the subclass override (see fun/demo/class-base.fun).

class UnicodeBase()
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

  // abstract: the backends override these
  fun fromBytes(s, cp)
    raise 'UnicodeBase.fromBytes is abstract';
  end fun;

  fun toBytes(s, cp)
    raise 'UnicodeBase.toBytes is abstract';
  end fun;

  fun utf8toGb2312(s)
    var ascii;
    if isUtf8(s, var ascii) and not ascii then
      result = this.fromBytes(s.toStr(), utf8);
      result = this.toBytes(result, gb2312);
      //result = result.replace(/\x0++$/, '');
    else
      result = s;
    end if;
  end fun;

  fun gb2312toUtf8(s)
    var ascii;
    if not isUtf8(s, var ascii) and not ascii then
      result = this.fromBytes(s.toStr(), gb2312);
      result = this.toBytes(result, utf8);
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
