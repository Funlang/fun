// Prototype: lib-os host dispatcher idiom (Linux backend).
//
// Goal (from art/notes/library-port-plan.md, step 1): prove that a single
// .fun module can serve several hosts while keeping ONE public API, because
// `use` is a static include (there is no conditional compilation in Fun).
//
// Validated idiom, in three rules:
//   1. Detect the host once, at load time, from 'host'.arg() (compile-time facts).
//   2. Resolve native handles ONLY on the host that owns them. A handle that is
//      resolved unconditionally would make the module fail to load on the other
//      host ("cannot load library ...").
//   3. Keep the public name/signature identical and put a one-line host branch
//      inside the wrapper. Pure helpers belong in lib-utils, not here.
//
// Why not a plain function pointer for the wrapper itself: Fun's `fun f(x)`
// form is partial application (it evaluates the arguments), so a wrapper still
// needs the branch. The function-pointer pattern in lib-os already applies to
// the *native handles* (var sleep = kernel32.getapi(...); sleep(ms)), which is
// exactly what rule 2 covers.
use 'fun/lib/lib-utils.fun';

//--------------------------------------------------------------
// 1. host detection
//--------------------------------------------------------------
var hostFacts = 'host'.arg().getJson(fd: true);
var isWindows = hostFacts.os = 'windows';
var isLinux   = hostFacts.os = 'linux';

//--------------------------------------------------------------
// 2. native handles, resolved per host
//--------------------------------------------------------------
var _usleep;          // Linux
var _system;          // Linux
var _kernelSleep;     // Windows
var _shellExecute;    // Windows

if isLinux then
  _usleep  = 'libc.so.6'.getapi('usleep', 'i:');   // void usleep(unsigned)
  _system  = 'libc.so.6'.getapi('system', 's:i');  // int system(const char*)
else
  _kernelSleep = 'kernel32'.getapi('Sleep', 'i:'); // Windows: ms, same unit
  // _shellExecute = 'shell32'.getapi('ShellExecute', 'issssi:i');
end if;

//--------------------------------------------------------------
// 3. public API: one name, one signature, thin host branch
//--------------------------------------------------------------
// sleep(ms)
fun sleep(ms)
  if isLinux then
    _usleep(ms * 1000);      // usleep takes microseconds
  else
    _kernelSleep(ms);
  end if;
end fun;

// exec(fn, ps, dir, show, op, win) -> fire and forget
fun exec(fn, ps, dir, show, op, win)
  var cmd = fn;
  if ps <> '' then cmd = cmd & ' ' & ps; end if;
  if isLinux then
    result = _system(cmd & ' &');   // detached: shell forks and returns
  else
    result = _shellExecute(win, op, fn, ps, dir, show);
  end if;
end fun;
var execShow(fn, ps, dir) = exec(fn, ps, dir, 1);

// execWait(fn, ps, dir, show, noWait, timeout, pid) -> wait for exit
// Linux result: the shell's exit status (Windows returns ShellExecute's code).
fun execWait(fn, ps, dir, show, noWait, timeout, pid)
  var cmd = fn;
  if ps <> '' then cmd = cmd & ' ' & ps; end if;
  if isLinux then
    if dir <> '' then cmd = 'cd ' & dir & ' && ' & cmd; end if;
    if noWait then cmd = cmd & ' &'; end if;
    result = _system(cmd);
  else
    // Windows backend (WScript.Shell / CreateProcess) goes here, unchanged.
    result = 0;
  end if;
end fun;
var execWaitShow(fn, ps, dir, noWait) = execWait(fn, ps, dir, 1, noWait);

//--------------------------------------------------------------
// smoke test on Linux
//--------------------------------------------------------------
if not isLinux then
  return;
end if;

var t1 = '/tmp/fun-osdisp-t1';
var t2 = '/tmp/fun-osdisp-t2';
_system('echo -n $(date +%s%3N) > ' & t1);
sleep(400);
_system('echo -n $(date +%s%3N) > ' & t2);
var elapsed = t2.load().toNum() - t1.load().toNum();
?. elapsed >= 350;

// fire and forget: the child writes the file while we keep going
exec('/bin/sh', '-c "echo -n $(date +%s%3N) > ' & '/tmp/fun-osdisp-t3' & '"', '', 0, '', 0);
sleep(200);
// epoch milliseconds: 13 digits; toNum() would wrap it to 32 bits (H-06)
?. '/tmp/fun-osdisp-t3'.load().length() = 13;

// wait for exit: shell exit status is preserved
?. execWait('/bin/sh', '-c "exit 7"', '', 0, false, 0, 0) div 256;
?. execWait('/bin/echo', 'dispatched', '', 0, false, 0, 0) div 256;
