// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-utils.fun';

var icmpdll = 'icmp.dll';
var icmpapi = [
      create : icmpdll.getapi('IcmpCreateFile',  ':i'),
      close  : icmpdll.getapi('IcmpCloseHandle', 'i:i'),
      send   : icmpdll.getapi('IcmpSendEcho',    'iisiisii:i')
        #*
          HANDLE                 IcmpHandle,
          IPAddr                 DestinationAddress,
          LPVOID                 RequestData,
          WORD                   RequestSize,
          PIP_OPTION_INFORMATION RequestOptions,
          LPVOID                 ReplyBuffer,
          DWORD                  ReplySize,
          DWORD                  Timeout
        #
];

fun ping(ip, timeout)
  result = new [];
  var h = icmpapi.create();
  if h >= 0 then
    var r = 0.toChar().x(1024);
    ip = ip2int(ip);
    var s = '[Hello, ICMP from Fun! @funlang.org]';
    icmpapi.send(h, ip, s, s.length(), 0, r, r.length(), timeout or 1000);
    icmpapi.close(h); //?. str2hex(r);
    result.IP     = int2ip(str2int(r.substr(0, 4)));
    result.Status = str2int(r.substr(4, 4));
    result.Time   = str2int(r.substr(8, 4));
    result.Size   = str2int(r.substr(12, 4));
    if result.Size > 0 then
      result.Data   = 0.toChar().x(result.Size); //?. str2int(r.substr(16, 4));
      str2int(r.substr(16, 4)).move(result.Data.toNum(-1), len: result.Size);
    end if;
  end if;
end fun;
