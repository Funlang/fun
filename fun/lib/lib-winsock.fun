// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-os.fun';
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

var WINSOCK_VER    = 0x0202;
var AF_INET        = 2;
var SOCK_STREAM    = 1;
var SOCK_DGRAM     = 2;
var IPPROTO_IP     = 0;
var IPPROTO_TCP    = 6;
var IPPROTO_UDP    = 17;
var SD_RECEIVE     = 0;
var SD_SEND        = 1;
var SD_BOTH        = 2;
var FD_READ        = 0x01;
var FD_WRITE       = 0x02;
var FD_OOB         = 0x04;
var FD_ACCEPT      = 0x08;
var FD_CONNECT     = 0x10;
var FD_CLOSE       = 0x20;
var BUFFERSIZE     = 8192;
var BackLog        = 5; // SOMAXCONN      = 5;
var SOL_SOCKET     = 0xffff;
var SO_BROADCAST   = 0x0020;
var ADD_MEMBERSHIP = 12; //5;
var CONNECT_TIME   = 0x700C;

var WinSock = 'Ws2_32.dll';
var SockAPI = [
    WSAStartup     : WinSock.getapi('WSAStartup',     'is:i'),     // version, WSData
    WSACleanup     : WinSock.getapi('WSACleanup',     ':i'),
    socket         : WinSock.getapi('socket',         'iii:i'),    // af, type, protocol
    closesocket    : WinSock.getapi('closesocket',    'i:i'),      // socket
    bind           : WinSock.getapi('bind',           'isi:i'),    // socket, addr16, addrlen
    connect        : WinSock.getapi('connect',        'isi:i'),    // socket, addr16, addrlen
    listen         : WinSock.getapi('listen',         'ii:i'),     // socket, backlog
    accept         : WinSock.getapi('accept',         'isi:i'),    // socket, nil, nil
    recv           : WinSock.getapi('recv',           'isii:i'),   // socket, buff, len, flags
    send           : WinSock.getapi('send',           'isii:i'),   // socket, buff, len, flags
    recvfrom       : WinSock.getapi('recvfrom',       'isiiss:i'), // socket, buff, len, flags, addr16, &addrlen
    sendto         : WinSock.getapi('sendto',         'isiisi:i'), // socket, buff, len, flags, addr16,  addrlen
    shutdown       : WinSock.getapi('shutdown',       'ii:i'),     // socket, sd_how
    getpeername    : WinSock.getapi('getpeername',    'iss:i'),    // socket, addr16, &addrlen
    getsockopt     : WinSock.getapi('getsockopt',     'iiiss:i'),  // socket, level, optname, optval, &optlen
    setsockopt     : WinSock.getapi('setsockopt',     'iiisi:i'),  // socket, level, optname, optval,  optlen
    getaddrinfo    : WinSock.getapi('getaddrinfo',    'ssss:i'),   // nodename, service, hints, result
    gethostbyname  : WinSock.getapi('gethostbyname',  'p:p'),      // name
    gethostbynamea : WinSock.getapi('WSAAsyncGetHostByName', 'iispi:i'), // hWnd, wMsg, name, buf, buflen
    WSAAsyncSelect : WinSock.getapi('WSAAsyncSelect', 'iiii:i'),   // socket, hwnd, msg, event
    WSAGetLastError: WinSock.getapi('WSAGetLastError',':i')
];

Startup();
fun Startup()
  SockAPI.WSAStartup(WINSOCK_VER, 0.toChar().x(1024));
end fun;

fun getHostByNamea(hWnd, wMsg, name, buf)
  SockAPI.gethostbynamea(hWnd, wMsg, name, buf, buf.length());
end fun;

fun getHostByName(name)
  var s = SockAPI.gethostbyname(name); // block if no internet
  if s = nil then
    raise FormatMessage(SockAPI.WSAGetLastError());
  end if;
  hostent2ip(s, var name);
end fun;

fun hostent2ip(s, ip)
  #*
    char  *h_name;
    char  **h_aliases;
    short h_addrtype;
    short h_length;
    char  **h_addr_list; #
  // s -> t
  var t = 0.toChar().x(16);
  s.move(t.toNum(-1), 16);
  // s = t.h_addr_list
  s = t.substr(12);
  // s^ -> t
  t = 0.toChar().x(4);
  str2int(s).move(t.toNum(-1), 4);
  // t^ -> ip
  ip = 0.toChar().x(4);
  str2int(t).move(ip.toNum(-1), 4); //?. str2hex(ip);
  result = int2ip(str2int(ip));
end fun;

fun Addr16(ip, port)
  port = port div 1; // convert to int
  port = port >> 8 + port mod 256 << 8;
  if ip =~ /[a-z]/i then
    getHostByName(var ip);
  else
    ip = int2str(ip2int(ip));
  end if; //?. str2hex(ip);
  result = int2str(AF_INET + port << 16) & ip & 0.toChar().x(8);
end fun;

fun Addr2IP(addr, port)
  port = ('0x' & str2hex(addr.substr(2, 2))).toNum();
  result = int2ip(str2int(addr.substr(4, 4)));
end fun;

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

fun TCPSocket()
  result = SockAPI.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
end fun;

fun UDPSocket()
  result = SockAPI.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
end fun;

class Server()
  #=====================================================================================================================
  # UDP
  #=====================================================================================================================
  class UDP(ip, port, onGet, broadCast) # onGet(data, ip, port)
    var handle = 0;
    var message;
    fun Start(hwnd, message) //?, ' try'; ?, ip; ?. port;
      handle = UDPSocket();
      result = SockAPI.bind(handle, Addr16(ip, port), 16) = 0;
      if result then
        try
          if broadCast then
            SockAPI.setsockopt(handle, SOL_SOCKET, SO_BROADCAST, int2str(1), 4);
            if not broadCast in [1, -1] then
              var c = int2str(ip2int(broadCast)) & 0.toChar().x(4);
              var r = SockAPI.setsockopt(handle, IPPROTO_IP, ADD_MEMBERSHIP, c, 8);
              if r <> 0 then
                ?. FormatMessage(SockAPI.WSAGetLastError());
              end if;
            end if;
          end if;
        except
          ?. @;
          ?. FormatMessage(SockAPI.WSAGetLastError());
        end try;
        if hwnd <> 0 then
          SockAPI.WSAAsyncSelect(handle, hwnd, message, FD_Read);
          this.message = message;
        end if;
      else
        Stop();
        raise FormatMessage(SockAPI.WSAGetLastError());
      end if;
    end fun;

    fun Send(ip, port, data)
      result = SockAPI.sendto(handle, data, data.length(), 0, Addr16(ip, port), 16);
    end fun;

    fun Stop()
      result = SockAPI.closesocket(handle) = 0;
      handle = 0;
    end fun;

    fun OnData()
      var b = 0.toChar().x(BUFFERSIZE); // todo: 大包怎么办
      var uc = 0.toChar().x(16); // 对端 UDP 信息: ip, port ...
      var ucl = int2str(16);
      var i = SockAPI.recvfrom(handle, b, BUFFERSIZE, 0, uc, ucl);
      b = b.substr(len: i);
      if i > 0 then //?. b;
        var port;
        var ip = Addr2IP(uc, var port); //?, ip; ?. port;
        onGet(b, ip, port);
      else
        //?. 'UDP.OnData: ' & FormatMessage(SockAPI.WSAGetLastError());
      end if;
    end fun;

    fun OnMessage(hwnd, msg, wParam, lParam);
      result = true;
      try
        case msg is
          when message do //?, wParam; ?. lParam;
            case lParam is
              when FD_Read do //?. 'read';
                OnData();
            end case;
        end case;
      except
        ?. 'Error(UDP.OnMessage): $@ at $@@()'.eval();
      end try;
    end fun;
  end class;

  #=====================================================================================================================
  # HTTP
  #=====================================================================================================================
  class HTTP(ip, port, onGet) # onGet(req/res, header, body, sock, args)
    var handle  = 0;
    var clients = new [];
    var clcount = 0;
    var queue   = Stack();
    var message;
    var connected = false;
    var onConnect = nil;

    fun Start(hwnd, message) //?, ' try'; ?, ip; ?. port;
      newSocket();
      result = SockAPI.bind(handle, Addr16(ip, port), 16) = 0 and
               SockAPI.listen(handle, BackLog) = 0;
      bindMessage(hwnd, message, result);
    end fun;

    fun TryConnect(hwnd, message) //?, ip; ?. port;
      newSocket();
      if hwnd <> nil then
        bindMessage(hwnd, message, handle <> nil, true);
      end if;
      var tmp = Addr16(ip, port);
      result = SockAPI.connect(handle, tmp, 16) = 0; //?. result;
    end fun;

    fun Connect(hwnd, message, onConnect)
      this.onConnect = onConnect;
      result = TryConnect(hwnd, message);
    end fun;

    fun Tunnel(host, auth)
      this.SendEx(`CONNECT $host HTTP/1.0$auth\r\n\r\n`.escape().eval());
    end fun;

    fun Stop()
      result = close(var handle);
    end fun;

    var iird = 0;
    fun OnMessage(hwnd, msg, wParam, lParam);
      result = true;
      try
        case msg is
          when message do //?, wParam; ?. lParam;
            case lParam is
              when FD_Read do            //?, 'read'; ?, wParam;
                var i = this.receive(wParam); //?, i; ?. iird; iird += 1;
              when FD_Accept do          //?, 'accept...';
                var id = '@' & SockAPI.accept(handle, nil, nil);
                this.clients[id] = new [len: -1]; //?. id;
                this.clcount += 1;
              when FD_Connect do         //?, 'connected.';
                this.connected = true;
                if this.onConnect <> nil then
                  this.onConnect();
                end if;
              when FD_Close do           //?. '-> close';
                this.close(wParam);
            end case;
        end case;
      except
        ?. 'Error(HTTP.OnMessage): $@ at $@@()'.eval();
      end try;
    end fun;

    fun Send(s, sock) //?. s;
      sock = sock or handle;
      var i = 0;
      var errs = 0;
      while i < s.length() and sock <> nil and errs < 100 do
        var b = s.substr(i, BUFFERSIZE); //?. b;
        var l = SockAPI.send(sock, b, b.length(), 0);
        if l > 0 then
          i += l;
          sleep(0);
          errs = 0;
        else
          check(l, var sock);
          sleep(30);
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
          SockAPI.shutdown(sock, SD_SEND);
          close(sock);
        end if;
      except
      end try;

      queue.pull();
      if not queue.isEmpty() then
        var q = queue.pull(true);
        this.onGet(q.req, q.header, q.body, q.sock);
      end if;
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

    #===========================================================================
    fun newSocket()
      result = handle and Stop();
      handle = TCPSocket();
      clients['@' & handle] = new [len: -1];
      clcount = 0;
    end fun;

    fun bindMessage(hwnd, message, ret, isClient)
      if ret then
        var f = FD_Read bit or FD_Accept bit or FD_Close;
        if isClient then
          f = f bit or FD_CONNECT;
        end if;
        SockAPI.WSAAsyncSelect(handle, hwnd, message, f);
        this.message = message;
      else
        var e = FormatMessage(SockAPI.WSAGetLastError());
        Stop();
        raise e;
      end if;
    end fun;

    fun receive(sock)
      var c = clients['@' & sock];
      var b = 0.toChar().x(BUFFERSIZE);
      var i = SockAPI.recv(sock, b, BUFFERSIZE, 0);
      result = i;
      if i > 0 then
        c.time = 1.time();
        c.text &= b.substr(len: i); //?. c.text;
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
          if op bit and 0x40 = 0x40 and c.gzip and zlib then // compress
            //?, wsData.length(); ?, echoBuff(wsData);
            wsData = inflate(wsData);
            //?, wsData.length();
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
        var i = SockAPI.WSAGetLastError(); //?, 'check'; ?. i;
        if i in [10038, 10050, 10052, 10053, 10054, 10057, 10060] then
          ?, i; ?, 'close dead client'; ?. c;
          close(var c);
        elsif i in [10035, 10058] then
        else
          ?. FormatMessage(SockAPI.WSAGetLastError());
        end if;
      end if;
    end fun;

    fun close(sock)
      //?. 'close: ' & sock;
      clients['@' & sock] = nil;
      result = SockAPI.closesocket(sock) = 0;
      if sock = handle then
        handle = nil;
      end if;
      sock = nil;

      clcount -= 1;
      if clients.@count() > 10000 and clcount < 1000 then
        var cs = new [];
        for k: v in clients do next when v = nil;
          cs[k] = v;
        end do;
        clients = cs;
      end if; //?. clients.@toJson(1);
    end fun;
  end class;
end class;