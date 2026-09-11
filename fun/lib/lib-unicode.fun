// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-math.fun';

var _osLinux = 'host'.arg().getJson(fd: true).os = 'linux';

//--------------------------------------------------------------
// Linux backend: pure-Fun GBK (CP936) <-> UTF-8.
//
// Windows uses kernel32 WideCharToMultiByte/MultiByteToWideChar, which do not
// exist here. The table below is 2-byte little-endian codepoints indexed by
// (lead-0x81)*191 + (trail-0x40); 0 means "unmapped". CP936 is GBK (a superset
// of GB2312), which is what the `gb2312 = 936` constant means on Windows.
//--------------------------------------------------------------
use ':gb2312.tbl' as _gbTbl;

fun _gbCp(lead, trail)
  result = 0;
  if lead >= 0x81 and lead <= 0xfe and trail >= 0x40 and trail <= 0xfe then
    var i = (lead - 0x81) * 191 + (trail - 0x40);
    result = _gbTbl.toByte(i * 2) + (_gbTbl.toByte(i * 2 + 1) << 8);
  end if;
end fun;

fun _u8Put(cp)
  if cp < 0x80 then
    result = cp.toChar();
  elsif cp < 0x800 then
    result = (0xc0 + (cp >> 6)).toChar() & (0x80 + (cp bit and 0x3f)).toChar();
  else
    result = (0xe0 + (cp >> 12)).toChar() &
             (0x80 + ((cp >> 6) bit and 0x3f)).toChar() &
             (0x80 + (cp bit and 0x3f)).toChar();
  end if;
end fun;

fun _u8Get(s, i)
  // Compute into locals first: a parameter-derived builtin call nested directly
  // inside a list literal is re-evaluated with a stale index on repeat calls
  // (Fun quirk observed 2026-09-11), which silently corrupted decoding.
  var c  = s.toByte(i);
  var cp = 0;
  var n  = 1;
  if c < 0x80 then
    cp = c;
  elsif c < 0xe0 then
    cp = ((c bit and 0x1f) << 6) + (s.toByte(i + 1) bit and 0x3f);
    n  = 2;
  elsif c < 0xf0 then
    cp = ((c bit and 0x0f) << 12) + ((s.toByte(i + 1) bit and 0x3f) << 6) + (s.toByte(i + 2) bit and 0x3f);
    n  = 3;
  else
    cp = 0;
    n  = 4; // 4-byte sequence: outside GBK, dropped
  end if;
  result = [cp, n];
end fun;

fun _gbToUtf8(s)
  result = '';
  var i = 0;
  while i < s.length() do
    var c = s.toByte(i);
    if c < 0x80 then
      result &= c.toChar();
      i += 1;
    else
      var cp = _gbCp(c, s.toByte(i + 1));
      if cp = 0 then
        i += 1;
      else
        result &= _u8Put(cp);
        i += 2;
      end if;
    end if;
  end do;
end fun;

var _gbRev = nil;
fun _gbRevInit()
  if _gbRev = nil then
    _gbRev = new [];
    for lead = 0x81 to 0xfe do
      for trail = 0x40 to 0xfe do
        if trail <> 0x7f then
          var cp = _gbCp(lead, trail);
          if cp <> 0 and _gbRev[cp] = nil then
            _gbRev[cp] = (lead << 8) + trail;
          end if;
        end if;
      end do;
    end do;
  end if;
end fun;

fun _utf8ToGb(s)
  _gbRevInit();
  result = '';
  var i = 0;
  while i < s.length() do
    var r = _u8Get(s, i);
    var cp = r[0];
    if cp < 0x80 then
      result &= cp.toChar();
    else
      var v = _gbRev[cp];
      if v <> nil then
        result &= (v >> 8).toChar() & (v bit and 0xff).toChar();
      end if;
    end if;
    i += r[1];
  end do;
end fun;

var Unicode = UnicodeClass();
class UnicodeClass()
  var apis = nil;
  if not _osLinux then
    apis = new [
      tobytes  : 'kernel32'.getapi('WideCharToMultiByte', 'iiripiii:i'),
      frombytes: 'kernel32'.getapi('MultiByteToWideChar', 'iiripi:i')
    ];
  end if;

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
    if _osLinux then
      // The Linux intermediate is UTF-8 (Windows uses a wide string); the
      // public utf8toGb2312/gb2312toUtf8 pair is unaffected by the difference.
      if cp = gb2312 then
        result = _gbToUtf8(s.toStr());
      elsif cp = utf8 then
        result = s.toStr();
      else
        raise 'fromBytes: code page $cp is not supported on Linux'.eval();
      end if;
    else
      var l = apis.frombytes(cp, 0, s, -1, 0, 0) * 2; //?. l;
      result = 0.toChar().x(l);
      var m = apis.frombytes(cp, 0, s, -1, result, l);
      result = result.substr(len: min(l, m*2));
    end if;
  end fun;

  fun toBytes(s, cp)
    if _osLinux then
      if cp = gb2312 then
        result = _utf8ToGb(s.toStr());
      elsif cp = utf8 then
        result = s.toStr();
      else
        raise 'toBytes: code page $cp is not supported on Linux'.eval();
      end if;
    else
      var l = apis.tobytes(cp, 0, s, -1, 0, 0, 0, 0); //?. l;
      result = 0.toChar().x(l);
      var m = apis.tobytes(cp, 0, s, -1, result, l, 0, 0);
      result = result.substr(len: min(l, m)).replace(/\x0++$/, '');
    end if;
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
