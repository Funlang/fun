// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-utils.fun';
use 'lib-math.fun';

var ZLIB_VERSION = "1.2.11";
var ZLIB_SIZE    = 14 * 4;
var ZLIB_MAX     = 2 ^ 30;
var ZLIB_BLOCK   = 256*1024;
var zlibdll = 'zlib.dll';
var zlib = nil;
try
  zlib = [
    compress:     zlibdll.getapi('compress',      'spsi:i'),
    uncompress:   zlibdll.getapi('uncompress',    'spsi:i'), # *
    deflateInit2: zlibdll.getapi('deflateInit2_', 'siiiiisi:i'),
    deflate:      zlibdll.getapi('deflate',       'si:i'),
    deflateEnd:   zlibdll.getapi('deflateEnd',    's:i'),
    inflateInit2: zlibdll.getapi('inflateInit2_', 'sisi:i'),
    inflate:      zlibdll.getapi('inflate',       'si:i'),
    inflateEnd:   zlibdll.getapi('inflateEnd',    's:i'), #
  ];
except ?. @;
end try;

fun compress(s, noheader)
  result = s;
  if zlib then
    var r = 0.toChar().x(s.length());
    var l = int2str(r.length());
    var ret = zlib.compress(r, l, s, s.length());
    if ret = 0 then
      result = r.substr(len: str2int(l));
      if noheader then
        result = (result.toByte(2) bit and 0xfe).toChar() & result.substr(3, -7) & '\x00\x00\xff\xff'.escape();
      end if;
    else ?, 'compress error:'; ?. ret;
    end if;
  end if;
end fun;

fun decompress(s, length)
  result = s;
  if zlib then
    var r = 0.toChar().x(length);
    var l = int2str(length);
    var ret = zlib.uncompress(r, l, s, s.length());
    if ret = 0 then
      result = r.substr(len: str2int(l));
    else ?, 'decompress error:'; ?. ret;
    end if;
  end if;
end fun;

var @PI = 0;  // ptr of in,  next_in
var @LI = 4;  // len of in,  avail_in
var @PO = 12; // ptr of out, next_out
var @LO = 16; // len of out, avail_out
var @LA = 20; // len of all, total_out
fun flate(s, inde, args, init)
  result = '';
  var zs = args?.zs? or 0.toChar().x(ZLIB_SIZE);
  var zp = zs.toNum(-1);
  int2str(s.toNum(-1))    .move(@PI+zp);
  int2str(s.length())     .move(@LI+zp);
  var ret = init and not args?.dontInit? and init(zs);
  var r = 0.toChar().x(ZLIB_BLOCK);
  var lr = 0;
  loop
    var more =  str2int(zs,     @LI);
    if more and str2int(zs,     @LO) = 0 then
      int2str(r.toNum(-1)).move(@PO+zp);
      int2str(ZLIB_BLOCK) .move(@LO+zp);
    end if;
    var       all = str2int(zs, @LA);
    if all > lr then
      result &= args?.rs?.Write?(r, all - lr) or r.substr(len: all - lr);
      lr = all;
    end if;
    ret = zlib[inde & 'flate'].call(zs, not args?.ws? and 4 or 0);
    //?, ret; ?. echoBuff(zs);
    exit when all = str2int(zs, @LA);
  end loop;
  ret = init and not args?.dontEnd? and zlib[inde & 'flateEnd'].call(zs);
  result = args?.rs?.Get?() or result;
end fun;

fun inflate(s, args)
  result = flate(s, 'in', args, zs -> zlib.inflateInit2(zs, -15, ZLIB_VERSION, ZLIB_SIZE));
end fun;

fun deflate(s, level, args) // ws frame for chrome
  result = flate(s, 'de', args, zs -> zlib.deflateInit2(zs, level or args?.level? or -1, 8, -15, 8, 0, ZLIB_VERSION, ZLIB_SIZE));
end fun;

fun echoBuff(s)
  result = str2hex(s).replace(/(?<=\w{8})/g, ' ');
end fun;