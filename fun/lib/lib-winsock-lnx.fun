// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT
//
// lib-winsock-lnx: the Linux backend of lib-winsock -- BSD sockets on libc.
//
// Scope: the SOCKET LAYER, hostname resolution and the SYNCHRONOUS servers
// (UDP and HTTP/WebSocket). Everything here runs on the CALLING thread with a
// plain poll(2) event loop and invokes its callbacks inline; there are no
// worker threads. See art/notes/linux-threading.md for why (Fun's per-function
// variable stack is not re-entrant across threads) -- that is the "async" step
// left for later.
//
// Why it is not a drop-in translation of lib-winsock.fun:
//   * The Windows class is bound to `WSAAsyncSelect(socket, hwnd, msg, event)`
//     plus a user32 message pump: datagrams/reads arrive as window messages and
//     OnMessage() dispatches them. There is no hwnd/message pump on Linux.
//   * The replacement is a poll(2) loop. For UDP it is Run/RunOnce; for HTTP it
//     is Run/RunOnce too (accept + per-client reads), with onGet() called inline.
//
//     var srv = Server.UDP('0.0.0.0', 9999, (data, ip, port){ ... });
//     $if srv.Start() then
//       srv.RunOnce(500);        // one poll+recv, for scripts that drive their own loop
//       // or: srv.Run(nil);    // block forever dispatching datagrams
//     end if;
//
//     var web = Server.HTTP('0.0.0.0', 8080, (req, header, body, sock){ ... });
//     web.Start();
//     web.Run(nil);              // handler calls web.Reply200(body, sock)
//
// Byte order / struct layout: BSD `sockaddr_in` on x86_64-linux is identical to
// WinSock's 16-byte layout (family:2 host-endian, port:2 big-endian, addr:4
// big-endian, then 8 zero bytes), so Addr16/Addr2IP are shared with the Windows
// file. The WebSocket framing / HTTP header parsing is protocol logic and is
// carried over from lib-winsock.fun (no OS calls in it).
//
// FFI notes (from lib-ajax-lnx / library-port-plan.md):
//   * native handles live in plain module-level variables, never in a set member;
//   * OUT parameters are passed as the REAL string address, `buf.toNum(-1)`, not
//     as 's' (which would hand libc a throw-away copy and lose the write);
//   * on input, 'i'/'l'/'n' all land in the same 8-byte GPR slot, so a raw
//     64-bit address survives regardless of the declared char.

use 'lib-utils.fun';
use 'lib-regex.fun';
use 'lib-stack.fun';
use 'lib-base64.fun';
use 'lib-zlib.fun';

var HTTP_CODEs = [
  @100: 'Continue',
  @101: 'Switching Protocols',
  @200: 'OK',
  @400: 'Bad Request',
  @401: 'Unauthorized',
  @403: 'Forbidden',
  @404: 'Not Found',
  @500: 'Internal Server Error'
];

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
var POLLERR       = 8;
var POLLHUP       = 16;
var POLLNVAL      = 32;
var SD_SEND       = 1;
var BUFFERSIZE    = 65536;   // one full UDP datagram
var HTTP_BUFSIZE  = 8192;    // TCP read chunk (same as lib-winsock.fun)
var BackLog       = 5;

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
var _getpeername = 'libc.so.6'.getapi('getpeername', 'iiii:i');
var _shutdown = 'libc.so.6'.getapi('shutdown', 'ii:i');
var _close    = 'libc.so.6'.getapi('close',    'i:i');
var _poll     = 'libc.so.6'.getapi('poll',     'iii:i');
var _memcpy   = 'libc.so.6'.getapi('memcpy',   'ppn:p');
var _errno_loc = 'libc.so.6'.getapi('__errno_location', ':p');
var _strerror = 'libc.so.6'.getapi('strerror', 'i:s');
var _usleep   = 'libc.so.6'.getapi('usleep',   'i:i');
var _getaddrinfo  = 'libc.so.6'.getapi('getaddrinfo',  'iiii:i');
var _freeaddrinfo = 'libc.so.6'.getapi('freeaddrinfo', 'i:i');
var _gai_strerror = 'libc.so.6'.getapi('gai_strerror', 'i:s');

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

// read one pointer-width (8-byte) little-endian value at byte offset off.
// str2int only reads 4 bytes, so assemble the high half explicitly.
fun ReadU64(s, off)
  var t = s.substr(off, 8);
  result = t.toNum(ptr: 1) + t.substr(4).toNum(ptr: 1) * 4294967296;
end fun;

//--------------------------------------------------------------
// hostname resolution (getaddrinfo; hostent's LP64 layout differs from WinSock)
//--------------------------------------------------------------
fun getHostByName(name)
  // numeric addresses need no lookup
  if name =~ %^\d+\.\d+\.\d+\.\d+$% then
    result = name;
    return;
  end if;
  // struct addrinfo is 48 bytes on x86_64; only ai_family/ai_socktype matter.
  var hints = 0.toChar().x(48);
  int2str(AF_INET)     .move(hints.toNum(-1) + 4);
  int2str(SOCK_STREAM) .move(hints.toNum(-1) + 8);
  var res = 0.toChar().x(8);
  var rc = _getaddrinfo(name.toNum(-1), 0, hints.toNum(-1), res.toNum(-1));
  if rc <> 0 then
    raise 'lib-winsock-lnx: cannot resolve host ' & name & ': ' & _gai_strerror(rc);
  end if;
  var p  = ReadU64(res, 0);              // struct addrinfo *
  var ai = 0.toChar().x(48);
  _memcpy(ai.toNum(-1), p, 48);
  var sa = ReadU64(ai, 24);              // ai_addr (struct sockaddr *)
  var sb = 0.toChar().x(16);
  _memcpy(sb.toNum(-1), sa, 16);
  var port;
  result = Addr2IP(sb, var port);        // numeric ip, port ignored
  _freeaddrinfo(p);
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
    ip = getHostByName(ip);
  end if;
  ip = int2str(ip2int(ip));
  result = int2str(AF_INET + port << 16) & ip & 0.toChar().x(8);
end fun;

fun Addr2IP(addr, port)
  port = ('0x' & str2hex(addr.substr(2, 2))).toNum();
  result = int2ip(str2int(addr.substr(4, 4)));
end fun;

// one int32 as a little-endian 4-byte buffer (for setsockopt optval / socklen)
fun IntBuf(v)
  result = int2str(v);
end fun;

fun ListenSocket(ip, port, backlog)
  var h = TCPSocket();
  if h < 0 then
    raise 'lib-winsock-lnx: socket: ' & ErrMsg();
  end if;
  _setsockopt(h, SOL_SOCKET, SO_REUSEADDR, IntBuf(1).toNum(-1), 4);
  var a = Addr16(ip, port);
  if _bind(h, a.toNum(-1), 16) <> 0 then
    var e = ErrMsg();
    _close(h);
    raise 'lib-winsock-lnx: bind ' & ip & ':' & port & ': ' & e;
  end if;
  if backlog = nil then
    backlog = BackLog;
  end if;
  if _listen(h, backlog) <> 0 then
    var e2 = ErrMsg();
    _close(h);
    raise 'lib-winsock-lnx: listen ' & ip & ':' & port & ': ' & e2;
  end if;
  result = h;
end fun;

// blocking connect: returns the connected handle or raises
fun ConnectSocket(ip, port)
  var h = TCPSocket();
  if h < 0 then
    raise 'lib-winsock-lnx: socket: ' & ErrMsg();
  end if;
  var a = Addr16(ip, port);
  if _connect(h, a.toNum(-1), 16) <> 0 then
    var e = ErrMsg();
    _close(h);
    raise 'lib-winsock-lnx: connect ' & ip & ':' & port & ': ' & e;
  end if;
  result = h;
end fun;

// accept one connection; returns the handle or nil when none is pending
fun AcceptSocket(h)
  var sa  = 0.toChar().x(16);
  var sal = IntBuf(16);
  var s = _accept(h, sa.toNum(-1), sal.toNum(-1));
  if s < 0 then
    result = nil;
  else
    result = s;
  end if;
end fun;

// send the whole string, blocking until done; returns bytes sent
fun SendAll(h, s)
  var i = 0;
  while i < s.length() loop
    var l = _send(h, s.substr(i).toNum(-1), s.length() - i, 0);
    if l > 0 then
      i += l;
    else
      raise 'lib-winsock-lnx: send: ' & ErrMsg();
    end if;
  end loop;
  result = i;
end fun;

// up to `size` bytes; nil on orderly EOF (peer closed)
fun RecvSome(h, size)
  var b = 0.toChar().x(size);
  var i = _recv(h, b.toNum(-1), size, 0);
  if i < 0 then
    raise 'lib-winsock-lnx: recv: ' & ErrMsg();
  elsif i = 0 then
    result = nil;
  else
    result = b.substr(0, i);
  end if;
end fun;

// read until the peer closes; nil if nothing arrived before EOF
fun RecvAll(h)
  var out = nil;
  loop
    var b = RecvSome(h, BUFFERSIZE);
    exit when b = nil;
    out = out or '';
    out &= b;
  end loop;
  result = out;
end fun;

fun Shutdown(h, how)
  if how = nil then how = SD_SEND; end if;
  result = _shutdown(h, how);
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

// remote ip/port of a connected socket: [ip, port]
fun PeerAddr(h)
  var uc  = 0.toChar().x(16);
  var ucl = IntBuf(16);
  if _getpeername(h, uc.toNum(-1), ucl.toNum(-1)) <> 0 then
    result = nil;
    return;
  end if;
  var port;
  var pip = Addr2IP(uc, var port);
  result = new [ip: pip, port: port];
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

//--------------------------------------------------------------
// WebSocket / HTTP protocol helpers (pure Fun, shared with lib-winsock.fun)
//--------------------------------------------------------------
fun getWebSocketAccept(key)
  result = hex2base64((key & '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').sha1());
end fun;

fun WebSocketHeaders(headers, body, upgrade)
  if upgrade = '' then
    upgrade = 'Upgrade';
  end if;
  var hs = new [];
  hs.Connection = 'keep-alive, Upgrade';
  hs[upgrade] = 'websocket';
  hs['Sec-WebSocket-Key'] = '%s=='.format((1.time()*1).x(2).replace('.','').substr(len:22));
  hs['Sec-WebSocket-Version'] = 13;
  hs['Content-Length'] = body.length();
  if headers then
    for k: v in headers do
      hs[k] = v;
    end do;
  end if;
  result = `
%s
%s`.format(getHeaders(hs), body);

  fun getHeaders(headers)
    result = '';
    if headers then
      for k: v in headers do
        result &= '$k: $v\r\n'.escape().eval();
      end do;
    end if;
  end fun;
end fun;

//--------------------------------------------------------------
// server
//--------------------------------------------------------------
class Server()
  #============================================================
  // UDP
  #============================================================
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

  #============================================================
  // HTTP / WebSocket (synchronous, poll(2), calling thread)
  #============================================================
  class HTTP(ip, port, onGet) # onGet(req/res, header, body, sock, args)
    var handle  = 0;
    var clients = new [];
    var clcount = 0;
    var queue   = Stack();
    var connected = false;
    var onConnect = nil;
    var running = false;

    //---- server --------------------------------------------------
    fun Start()
      newSocket();
      _setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, IntBuf(1).toNum(-1), 4);
      var a = Addr16(ip, port);
      if _bind(handle, a.toNum(-1), 16) <> 0 or _listen(handle, BackLog) <> 0 then
        var e = ErrMsg();
        Stop();
        raise 'lib-winsock-lnx HTTP: listen ' & ip & ':' & port & ': ' & e;
      end if;
      result = true;
    end fun;

    fun LocalPort()
      var la = LocalAddr(handle);
      if la = nil then
        result = 0;
      else
        result = la.port;
      end if;
    end fun;

    //---- client --------------------------------------------------
    // blocking connect (the Windows version is WSAAsyncSelect/FD_CONNECT)
    fun Connect(onConnect)
      this.onConnect = onConnect;
      newSocket();
      var a = Addr16(ip, port);
      if _connect(handle, a.toNum(-1), 16) <> 0 then
        var e = ErrMsg();
        Stop();
        raise 'lib-winsock-lnx HTTP: connect ' & ip & ':' & port & ': ' & e;
      end if;
      this.connected = true;
      if this.onConnect <> nil then
        this.onConnect();
      end if;
      result = true;
    end fun;

    fun Tunnel(host, auth)
      this.SendEx(`CONNECT $host HTTP/1.0$auth\r\n\r\n`.escape().eval());
    end fun;

    fun Stop()
      this.running = false;
      var dead = new [];
      for k: c in this.clients do
        if c <> nil then
          dead.@add(k.substr(1).toNum());
        end if;
      end do;
      for s in dead do
        _close(s);
      end do;
      this.clients = new [];
      this.clcount = 0;
      this.handle = 0;
      this.connected = false;
      result = true;
    end fun;

    //---- event loop ---------------------------------------------
    // one poll over the listening socket + every live client; accepts at most
    // one connection and dispatches reads. timeout = ms, nil = block.
    fun RunOnce(timeout)
      var h = this.handle;
      if h = nil or h = 0 then
        result = 0;
        return;
      end if;
      var fds = new [];
      var buf = '';
      for k: c in this.clients do
        next when c = nil;
        var s = k.substr(1).toNum();
        fds.@add(s);
        buf &= int2str(s) & int2str(POLLIN).substr(0, 2) & int2str(0).substr(0, 2);
      end do;
      if fds.@count() = 0 then
        result = 0;
        return;
      end if;
      var t = -1;
      if timeout <> nil then t = timeout div 1; end if;
      var n = _poll(buf.toNum(-1), fds.@count(), t);
      if n <= 0 then
        result = 0;
        return;
      end if;
      var cnt = 0;
      for i = 0 to fds.@count() - 1 do
        var revents = str2int(buf.substr(i * 8 + 4, 4)) >> 16 bit and 0xFFFF;
        if revents <> 0 then
          var s = fds[i];
          if s = this.handle and not this.connected then
            var a = AcceptSocket(s);
            if a <> nil then
              this.clients['@' & a] = new [len: -1];
              this.clcount += 1;
              cnt += 1;
            end if;
          else
            this.receive(s);
            cnt += 1;
          end if;
        end if;
      end do;
      result = cnt;
    end fun;

    // block on the calling thread until Stop() (from a handler) is called.
    fun Run(timeout)
      this.running = true;
      while this.running loop
        this.RunOnce(timeout);
      end loop;
    end fun;

    //---- I/O -----------------------------------------------------
    fun Send(s, sock) //?. s;
      sock = sock or handle;
      var i = 0;
      var errs = 0;
      while i < s.length() and sock <> nil and errs < 100 do
        var b = s.substr(i, HTTP_BUFSIZE); //?. b;
        var l = _send(sock, b.toNum(-1), b.length(), 0);
        if l > 0 then
          i += l;
          _usleep(0);
          errs = 0;
        else
          check(l, var sock);
          _usleep(30000);
          errs += 1;
        end if;
      end do;
    end fun;

    fun SendEx(s, sock)
      ?. s;
      this.Send(s, sock);
    end fun;

    fun SendWebSocketRequest(url, sock, headers, body, upgrade)
      this.SendEx(`GET $url HTTP/1.1`.eval() & WebSocketHeaders(headers, body, upgrade), sock);
    end fun;

    fun Reply(s, sock, args) //?. s;
      sock = sock or handle;
      var c = clients['@' & sock];
      if c = nil then
        result = false;
        return;
      end if;
      if c.wsMode then //?. 'WebSocket Reply';
        var op = 0x81; // text, 0x82 - binary
        if args and args.bin then
          op = 0x82;
        end if;
        var ll = s.length();
        if ll > 1024*1024 then
          ?, 'Sent ' & ll;
        end if;
        var s2;
        if c.gzip and zlib and ll > 1024*4 then // compress
          s2 = deflate(s, args: [ws: args and args.ws]);
          if ll > 1024*1024 then
            ?. '-> ' & s2.length();
          end if;
          if s2 <> nil then
            s = s2;
            op = op bit or 0x40;
          end if;
        elsif args and args.gziped then
          op = op bit or 0x40;
        end if;
        var l = s.length(); //?, 'Sent: $l'.eval();
        var b2 = l;
        var l2 = '';
        if l > 2^16 then
          b2 = 127;
          var high = (l >> 32) & 0xFFFFFFFF;
          var low  = l & 0xFFFFFFFF;
          l2 = int2str(high).x(-1) & int2str(low).x(-1);
        elsif l > 125 then
          b2 = 126;
          l2 = (l div 256).toChar() & (l mod 256).toChar();
        end if;
        if c.wsHeader = nil and c.wsCompatible then
          b2 = b2 bit or 0x80;
          l2 &= 0.toChar().x(4);
        end if;
        s = b2.toChar() & l2 & s;
        if args then
          if args.pong then
            op = 0x8a;
          elsif args.ping and l <= 125 then
            op = 0x89;
          end if;
        end if;
        s = op.toChar() & s;
        //?, ll; ?, s2.length(); ?. echoBuff(s);
      end if;

      Send(s, sock);
      try
        if c.close then
          _shutdown(sock, SD_SEND);
          close(sock);
        end if;
      except
      end try;

      queue.pull();
      if not queue.isEmpty() then
        var q = queue.pull(true);
        this.onGet(q.req, q.header, q.body, q.sock);
      end if;
      result = true;
    end fun;

    fun HttpCode(c)
      c = c or 400;
      result = 'HTTP/1.1 $c '.eval() & HTTP_CODEs['@' & c] & '\r\n'.escape();
    end fun;

    fun Reply200(s, sock, headers)
      this.ReplyWithCode(s, 200, sock, headers);
    end fun;

    fun ContentType()
      result = 'text/plain';
    end fun;

    fun Reply404(s, sock)
      this.ReplyWithCode(s, 404, sock);
    end fun;

    fun ReplyWithCode(s, code, sock, headers)
      if code = nil then
        code = 200;
      end if;
      this.Reply(this.HttpText(s, code, headers), sock);
    end fun;

    fun HttpText(s, code, headers)
      headers = headers or new []; //?. headers.@toJson();
      if headers['Content-Type'] = nil then
        headers['Content-Type'] = this.ContentType();
      end if; //?. headers.@toJson();
      var i = s.length();
      result = this.HttpCode(code) & this.HttpHeaders(headers) & 'Content-Length: $i\r\n\r\n$s'.escape().eval();
    end fun;

    fun HttpHeaders(headers)
      result = '';
      if headers then
        for k: v in headers do
          result &= '$k: $v\r\n'.escape().eval();
        end do;
      end if;
    end fun;

    fun newSocket()
      if this.handle <> nil and this.handle > 0 then
        Stop();
      end if;
      handle = TCPSocket();
      if handle < 0 then
        handle = 0;
        raise 'lib-winsock-lnx HTTP: socket: ' & ErrMsg();
      end if;
      this.clients = new [];
      this.clients['@' & handle] = new [len: -1];
      clcount = 0;
    end fun;

    fun receive(sock)
      var c = clients['@' & sock];
      if c = nil then
        result = -1;
        return;
      end if;
      var b = 0.toChar().x(HTTP_BUFSIZE);
      var i = _recv(sock, b.toNum(-1), HTTP_BUFSIZE, 0);
      if i <= 0 then
        close(sock);
        result = i;
        return;
      end if;
      c.time = 1.time();
      c.text &= b.substr(0, i); //?. c.text;
      if c.wsMode then //?. 'WebSocket'; // WebSocket
        onWsReceive(sock, c);
      elsif c.len = -1 and c.text =~ /\r?\n\r?\n/ then
        try
          if c.text =~ /^Connection:\sclose$/mi then
            // c.close = true; // 不要主动关闭连接，nginx 可能重用连接
          end if;
          c.len = c.text.match(/(?<=Content-Length:\s)\d++/).@@() div 1; //?. c.len;
        except
          c.len = 0; //?. 'Content-Length missing.';
        end try;
      end if;

      if c.len >= 0 and not c.wsMode and c.text.match(/\r?\n\r?\n(.++)$/s).@(1).length() >= c.len then //?. c.text;
        loop
          var last = c.text;
          if c.wsMode then
            onWsReceive(sock, c);
          else
            onReceive(sock, c);
          end if;
          exit when c.text = '' or c.text = last;
        end loop;
      end if;
      result = i;
    end fun;

    fun onWsReceive(sock, c)
      loop
        var wsData = c.text;
        var op;
        if c.len < 0 then
          op = wsData.toByte(0);
          var b2 = wsData.toByte(1);
          c.bs = 2;
          c.isMask = b2 bit and 0x80 <> 0;
          b2 = b2 bit and 0x7f;
          c.len = b2; //?, 'Received: ' & c.len; ?. str2hex(wsData);
          if b2 = 126 then
            c.len = wsData.toByte(2) << 8 + wsData.toByte(3);
            c.bs += 2;
          elsif b2 = 127 then
            c.len = str2int(wsData.substr(6, 4)); // low-32bits, high-32bits ignored.
            c.bs += 8;
          end if;
          if c.isMask then
            c.mask = new [wsData.toByte(c.bs), wsData.toByte(c.bs+1), wsData.toByte(c.bs+2), wsData.toByte(c.bs+3)];
            c.bs += 4;
          end if;
        end if; //?, wsData.length(); ?, c.bs; ?. c.len;

        if wsData.length() >= c.bs + c.len then
          c.text = wsData.substr(c.bs + c.len); //?, c.len;
          wsData = wsData.substr(c.bs,  c.len); //?. '[$wsData]'.eval() & wsData.length();
          c.len  = -1;
          if c.isMask then // 2026-04-10, before inflate
            wsData = wsEncode(wsData, c.mask);
          end if; //?. wsData;
          if op bit and 0x40 = 0x40 then // compressed frame
            if c.gzip and zlib then
              wsData = inflate(wsData);
            end if;
          end if;
          this.onGet(c.wsURL, c.wsHeader, wsData, sock, new [webSocket: true, op: op]);
          exit when c.text = '';
        else
          exit;
        end if;
      end loop;
    end fun;

    fun wsEncodeX(s, mask, skipNonAnsi)
      var i = 0;
      result = s.replace(/./gs, (m){
        var b = m.@@().toByte(0);
        if not skipNonAnsi or b < 0x80 then
          result = (b bit xor mask[i mod 4]).toChar();
          i += 1;
        else
          result = m.@@();
        end if;
      });
    end fun;

    fun wsEncode(s, mask, skipNonAnsi)
      try
        'a'.fromByte(0, 0);
      except
        return wsEncodeX(s, mask, skipNonAnsi);
      end try;

      var j = 0;
      for i = 0 to s.length() - 1 do
        var b = s.toByte(i);
        if not skipNonAnsi or b < 0x80 then
          s.fromByte(i, (b bit xor mask[j mod 4]));
          j += 1;
        end if;
      end do;
      result = s;
    end fun;

    fun onReceive(sock, c)
      var body;
      var header = splitonce(/\r?\n\r?\n/, c.text, var body); //?. header; ?. body;
      if c.len = 0 then
        c.text = body;
        body = '';
      else
        c.text = '';
      end if;
      c.len  = -1;
      if sock <> handle then // server
        var req = header.match(%^\w++\s(?:https?://[^/]++)?([^\r\n]+?)\sHTTP/[\d\.]++([\r\n]|$)%).@(1); //?. req;
        if header =~ /^FX-Queue:\strue$/mi then // FX-Queue: true
          queue.push(new [req: req, header: header, body: body, sock: sock]); //?. queue.count();
          if queue.count() = 1 then
            var q = queue.pull(true);
            this.onGet(q.req, q.header, q.body, q.sock);
          end if;
        elsif header =~ /^Upgrade:\swebsocket$/mi then ?. 'WebSocket handshake response.';
          var gzip = '';
          c.gzip = not not (zlib and header =~ /Sec-WebSocket-Extensions:\x20permessage-deflate/);
          if c.gzip then
            gzip = 'Sec-WebSocket-Extensions: permessage-deflate; client_no_context_takeover; server_no_context_takeover
';
          end if;
          var accept = getWebSocketAccept(header.match(/^Sec-WebSocket-Key:\s*+(.++)$/mi).@(1));
          Reply(HttpCode(101) & 'Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: $accept
$gzip
'.eval(), sock);
          c.wsHeader = header;
          c.wsURL    = req;
          c.wsMode   = true;
        else
          this.onGet(req, header, body, sock);
        end if;
      else                   // client
        if header =~ %^HTTP/\d\.\d\s101%mi and header =~ /^Upgrade:\swebsocket$/mi then ?. 'WebSocket handshake connected.';
          c.wsMode   = true;
          c.wsCompatible = true;
          c.gzip = not not header =~ /Sec-WebSocket-Extensions:\x20permessage-deflate/;
        end if;
        var res = header.match(%^HTTP/[\.\d]++\s(\d++)%).@(1); //?. res;
        this.onGet(res, header, body, sock);
      end if;
    end fun;

    fun check(ret, c)
      if ret < 0 then
        var i = Errno(); //?, 'check'; ?. i;
        if i in [9, 32, 104, 107, 110] then // EBADF, EPIPE, ECONNRESET, ENOTCONN, ETIMEDOUT
          close(var c);
        end if;
      end if;
    end fun;

    fun close(sock)
      //?. 'close: ' & sock;
      clients['@' & sock] = nil;
      result = _close(sock) = 0;
      if sock = handle then
        handle = 0;
      end if;
      sock = nil;

      clcount -= 1;
      if clients.@count() > 10000 and clcount < 1000 then
        var cs = new [];
        for k: v in clients do next when v = nil;
          cs[k] = v;
        end do;
        this.clients = cs;
      end if; //?. clients.@toJson(1);
    end fun;
  end class;
end class;
