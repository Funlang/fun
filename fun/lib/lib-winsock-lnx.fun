// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT
//
// lib-winsock-lnx: the Linux backend of lib-winsock -- BSD sockets on libc.
//
// Scope (first cut, deliberate): the SOCKET LAYER + a UDP server. HTTP / WebSocket
// (the big Server.HTTP class in lib-winsock.fun) is not here yet.
//
// Why it cannot be a drop-in translation:
//   * The Windows class is bound to `WSAAsyncSelect(socket, hwnd, msg, event)` plus
//     a user32 message pump: datagrams arrive as window messages and OnMessage()
//     dispatches them. There is no hwnd/message pump on Linux.
//   * The replacement is a plain poll(2) event loop that runs on the CALLING
//     thread and invokes onGet() inline. It is single-threaded on purpose:
//     see art/notes/notes on threading -- evaluating Fun concurrently from two
//     threads crashes the interpreter, so worker-thread servers are not safe yet.
//
//     var srv = Server.UDP('0.0.0.0', 9999, (data, ip, port){ ... });
//     $if srv.Start() then
//       srv.RunOnce(500);        // one poll+recv, for scripts that drive their own loop
//       // or: srv.Run(nil);    // block forever dispatching datagrams
//     end if;
//
// Byte order / struct layout: BSD `sockaddr_in` on x86_64-linux is identical to
// WinSock's 16-byte layout (family:2 host-endian, port:2 big-endian, addr:4
// big-endian, then 8 zero bytes), so Addr16/Addr2IP are reused verbatim.
//
// FFI notes (from lib-ajax-lnx / library-port-plan.md):
//   * native handles live in plain module-level variables, never in a set member;
//   * OUT parameters are passed as the REAL string address, `buf.toNum(-1)`, not
//     as 's' (which would hand libc a throw-away copy and lose the write);
//   * on input, 'i'/'l'/'n' all land in the same 8-byte GPR slot, so a raw
//     64-bit address survives regardless of the declared char.

use 'lib-utils.fun';

//--------------------------------------------------------------
// constants (Linux values; several differ from the WinSock numbers)
//--------------------------------------------------------------
var AF_INET       = 2;
var SOCK_STREAM   = 1;
var SOCK_DGRAM    = 2;
var IPPROTO_IP    = 0;
var IPPROTO_TCP   = 6;
var IPPROTO_UDP   = 17;
var SOL_SOCKET    = 1;
var SO_REUSEADDR  = 2;
var SO_BROADCAST  = 6;
var IP_ADD_MEMBERSHIP = 35;
var POLLIN        = 1;
var BUFFERSIZE    = 65536;   // one full UDP datagram

//--------------------------------------------------------------
// libc handles (plain module-level vars)
//--------------------------------------------------------------
var _socket   = 'libc.so.6'.getapi('socket',   'iii:i');
var _bind     = 'libc.so.6'.getapi('bind',     'iii:i');
var _connect  = 'libc.so.6'.getapi('connect',  'iii:i');
var _listen   = 'libc.so.6'.getapi('listen',   'ii:i');
var _accept   = 'libc.so.6'.getapi('accept',   'iii:i');
var _send     = 'libc.so.6'.getapi('send',     'iiii:l');
var _recv     = 'libc.so.6'.getapi('recv',     'iiii:l');
var _sendto   = 'libc.so.6'.getapi('sendto',   'iiiiii:l');
var _recvfrom = 'libc.so.6'.getapi('recvfrom', 'iiiiii:l');
var _setsockopt = 'libc.so.6'.getapi('setsockopt', 'iiiiii:i');
var _getsockname = 'libc.so.6'.getapi('getsockname', 'iiii:i');
var _shutdown = 'libc.so.6'.getapi('shutdown', 'ii:i');
var _close    = 'libc.so.6'.getapi('close',    'i:i');
var _poll     = 'libc.so.6'.getapi('poll',     'iii:i');
var _memcpy   = 'libc.so.6'.getapi('memcpy',   'ppn:p');
var _errno_loc = 'libc.so.6'.getapi('__errno_location', ':p');
var _strerror = 'libc.so.6'.getapi('strerror', 'i:s');

//--------------------------------------------------------------
// errors
//--------------------------------------------------------------
fun Errno()
  var b = 0.toChar().x(4);
  _memcpy(b.toNum(-1), _errno_loc(), 4);
  result = str2int(b);
end fun;

fun ErrMsg()
  var e = Errno();
  result = _strerror(e) & ' (' & e & ')';
end fun;

//--------------------------------------------------------------
// socket primitives
//--------------------------------------------------------------
fun TCPSocket()
  result = _socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
end fun;

fun UDPSocket()
  result = _socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
end fun;

// 16-byte sockaddr_in; same bytes WinSock wants.
fun Addr16(ip, port)
  port = port div 1;
  port = port >> 8 + port mod 256 << 8;
  if ip =~ /[a-z]/i then
    // hostname resolution is not wired up yet (getHostByName's hostent layout is
    // 4-byte-pointer shaped in lib-winsock and wrong on LP64); numeric only.
    raise 'lib-winsock-lnx: hostname addresses are not supported yet: ' & ip;
  else
    ip = int2str(ip2int(ip));
  end if;
  result = int2str(AF_INET + port << 16) & ip & 0.toChar().x(8);
end fun;

fun Addr2IP(addr, port)
  port = ('0x' & str2hex(addr.substr(2, 2))).toNum();
  result = int2ip(str2int(addr.substr(4, 4)));
end fun;

// one int32 as a little-endian 4-byte buffer (for setsockopt optval)
fun IntBuf(v)
  result = int2str(v);
end fun;

// client-style helpers on a bare UDPSocket()/TCPSocket() handle
fun SendTo(h, ip, port, data)
  var a = Addr16(ip, port);
  result = _sendto(h, data.toNum(-1), data.length(), 0, a.toNum(-1), 16);
end fun;

// block up to `timeout` ms (nil = forever) for one datagram; returns
// [data, ip, port, size] or nil on timeout.
fun RecvFrom(h, timeout)
  var t = -1;
  if timeout <> nil then t = timeout; end if;
  var pfd = int2str(h) & int2str(POLLIN).substr(0, 2) & int2str(0).substr(0, 2);
  if _poll(pfd.toNum(-1), 1, t) <= 0 then
    result = nil;
    return;
  end if;
  var b   = 0.toChar().x(BUFFERSIZE);
  var uc  = 0.toChar().x(16);
  var ucl = IntBuf(16);
  var i = _recvfrom(h, b.toNum(-1), BUFFERSIZE, 0, uc.toNum(-1), ucl.toNum(-1));
  if i <= 0 then
    result = nil;
    return;
  end if;
  var port;
  var pip = Addr2IP(uc, var port);
  result = new [data: b.substr(0, i), ip: pip, port: port, size: i];
end fun;

fun CloseSocket(h)
  result = _close(h);
end fun;

// local ip/port a socket is bound to: [ip, port]. Useful after binding port 0.
fun LocalAddr(h)
  var uc  = 0.toChar().x(16);
  var ucl = IntBuf(16);
  if _getsockname(h, uc.toNum(-1), ucl.toNum(-1)) <> 0 then
    result = nil;
    return;
  end if;
  var port;
  var pip = Addr2IP(uc, var port);
  result = new [ip: pip, port: port];
end fun;

//--------------------------------------------------------------
// server
//--------------------------------------------------------------
class Server()
  //============================================================
  // UDP
  //============================================================
  class UDP(ip, port, onGet, broadCast) # onGet(data, ip, port)
    var handle  = 0;
    var running = false;

    fun Start()
      handle = UDPSocket();
      if handle < 0 then
        handle = 0;
        raise 'lib-winsock-lnx UDP: socket: ' & ErrMsg();
      end if;
      _setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, IntBuf(1).toNum(-1), 4);
      if broadCast then
        _setsockopt(handle, SOL_SOCKET, SO_BROADCAST, IntBuf(1).toNum(-1), 4);
        if broadCast <> true and broadCast <> 1 and broadCast <> -1 then
          // join a multicast group: struct ip_mreq { group; interface=0.0.0.0 }
          var m = int2str(ip2int(broadCast)) & 0.toChar().x(4);
          if _setsockopt(handle, IPPROTO_IP, IP_ADD_MEMBERSHIP, m.toNum(-1), 8) <> 0 then
            Stop();
            raise 'lib-winsock-lnx UDP: IP_ADD_MEMBERSHIP: ' & ErrMsg();
          end if;
        end if;
      end if;
      var a = Addr16(ip, port);
      if _bind(handle, a.toNum(-1), 16) <> 0 then
        var e = ErrMsg();
        Stop();
        raise 'lib-winsock-lnx UDP: bind ' & ip & ':' & port & ': ' & e;
      end if;
      result = true;
    end fun;

    // the port actually bound (meaningful when constructed with port 0)
    fun LocalPort()
      var la = LocalAddr(handle);
      if la = nil then
        result = 0;
      else
        result = la.port;
      end if;
    end fun;

    fun Send(ip, port, data)
      var a = Addr16(ip, port);
      result = _sendto(handle, data.toNum(-1), data.length(), 0, a.toNum(-1), 16);
    end fun;
    fun Stop()
      this.running = false;
      if handle > 0 then
        _close(handle);
      end if;
      handle = 0;
      result = true;
    end fun;

    // receive at most one datagram and dispatch onGet; returns bytes received
    fun OnData()
      var b   = 0.toChar().x(BUFFERSIZE);
      var uc  = 0.toChar().x(16);
      var ucl = IntBuf(16);
      var i = _recvfrom(handle, b.toNum(-1), BUFFERSIZE, 0, uc.toNum(-1), ucl.toNum(-1));
      if i > 0 then
        var port;
        var pip = Addr2IP(uc, var port);
        this.onGet(b.substr(0, i), pip, port);
      end if;
      result = i;
    end fun;

    // one poll + recv; timeout = milliseconds, nil = block until one datagram
    fun RunOnce(timeout)
      var t = -1;
      if timeout <> nil then t = timeout; end if;
      var pfd = int2str(handle) & int2str(POLLIN).substr(0, 2) & int2str(0).substr(0, 2);
      if _poll(pfd.toNum(-1), 1, t) > 0 then
        result = this.OnData();
      else
        result = 0;
      end if;
    end fun;

    // event loop on the calling thread; timeout = poll timeout per iteration
    // (nil = block). Stop() from inside onGet() ends it.
    fun Run(timeout)
      this.running = true;
      var t = -1;
      if timeout <> nil then t = timeout; end if;
      var pfd = int2str(handle) & int2str(POLLIN).substr(0, 2) & int2str(0).substr(0, 2);
      while this.running loop
        if _poll(pfd.toNum(-1), 1, t) > 0 then
          this.OnData();
        end if;
      end loop;
    end fun;
  end class;
end class;
