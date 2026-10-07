// Prototype: portable command line for Linux (proposal for lib-cmdline).
//
// Windows lib-cmdline gets everything from kernel32.GetCommandLine and assumes
// .exe / .ini / '\\' paths. None of that holds on Linux. What Linux actually
// offers:
//   * N.arg()          -> argv: 0 = executable (already absolute), 1 = script,
//                          2.. = user args; there is NO argc builtin, so the
//                          scan stops at the first empty arg.
//   * readlink('/proc/self/exe') -> the resolved executable path (out-buffer
//                          via toNum(-1), verified in fun/test/libc-outbuf.fun)
//   * no '.exe'/'.ini' suffixes: drop that derivation on Linux.
//
// Design questions for the author are marked [DECIDE] below.
use 'fun/lib/lib-host.fun';

fun DirName(p)
  result = p.replace(%[^/]*$%, '');   // keep the trailing separator, like lib-os
end fun;

fun Argv()
  result = new [];
  var i = 1;
  while i.arg() <> '' do
    result.@add(i.arg());
    i += 1;
  end do;
end fun;

fun ParseOptions(argv)
  result = new [];
  var i = 0;
  while i < argv.@count() do
    var a = argv[i];
    if a =~ %^(--|-|/)% then
      var body = a.replace(%^(--|-|/)%, '');
      var eq = body.subpos('=');
      if eq >= 0 then
        // POSIX style: --key=value  [DECIDE] keep this in addition to the
        // Windows 'next argument' style below?
        result[body.substr(0, eq)] = body.substr(eq + 1);
      elsif i + 1 < argv.@count() and argv[i+1] !~ %^(--|-|/)% then
        result[body] = argv[i+1];
        i += 1;
      else
        result[body] = true;
      end if;
    end if;
    i += 1;
  end do;
end fun;

// Port of lib-cmdline's GetCmdLineParams for Linux.
fun GetCmdLineParams()
  // NOTE: do NOT name this local 'argv' - Fun identifiers are case-insensitive,
  // so it would collide with the Argv() function and resolve to the function.
  var argvs = Argv();
  result = new [];
  result.@exe  = 0.arg();            // [DECIDE] exe = argv[0] as given, or the
                                     // readlink('/proc/self/exe') resolved path?
  result.@path = DirName(result.@exe);
  var f = '';
  if argvs.@count() > 0 then f = argvs[0]; end if;
  result.@fun  = f;
  result.args  = argvs;
  result.options = ParseOptions(argvs);
  // [DECIDE] no .exe / .ini derivation on Linux (Windows-only concepts)
end fun;

var CmdLineParams = GetCmdLineParams();

// --- assertions that hold for any invocation ---------------------------
?. CmdLineParams.@exe.substr(0, 1) = '/';                    // absolute
?. CmdLineParams.@path = CmdLineParams.@exe.replace(%[^/]*$%, '');
?. CmdLineParams.@path.match(%/$%) != nil;                   // trailing sep
?. CmdLineParams.@fun = 1.arg();
?. CmdLineParams.args.@count() >= 1;
?. CmdLineParams.args[0] = 1.arg();
