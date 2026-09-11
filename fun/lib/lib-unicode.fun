// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

// lib-unicode (Windows backend): charset conversion through kernel32
// WideCharToMultiByte / MultiByteToWideChar.
//
// Shared logic (constants, isUtf8/isGb2312, utf8toGb2312/gb2312toUtf8) lives in
// lib-unicode-base.fun. The Linux backend is lib-unicode-lnx.fun.

use 'lib-math.fun';       // min()
use 'lib-unicode-base.fun';

var Unicode = UnicodeClass();
class UnicodeClass = UnicodeBase()
  var apis = new [
    tobytes  : 'kernel32'.getapi('WideCharToMultiByte', 'iiripiii:i'),
    frombytes: 'kernel32'.getapi('MultiByteToWideChar', 'iiripi:i')
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
end class;
