// lib-cmdline-lnx: POSIX command-line parsing (run with no extra args).
// Host-dependent (asserts absolute paths from N.arg()), snap-friendly.
use 'fun/lib/lib-cmdline-lnx.fun';

?. CmdLineParams.@exe.substr(0, 1) = '/';
?. CmdLineParams.@path = CmdLineParams.@exe.replace(%[^/]*$%, '');
?. CmdLineParams.@fun = 1.arg();
?. CmdLineParams.args[0] = 0.arg();
?. CmdLineParams.args[1] = 1.arg();
?. CmdLineParams.options.@count() = 0;

?. cmdLineArgs.isFUN;
?. cmdLineArgs.argc = 1;
?. cmdLineArgs.argv[0] = HostFullPath(1.arg());
?. cmdLineArgs.exe = 0.arg();

// ParseOptions: --key=value, -k value, and a bare flag.
var m = new ['prog', 'script.fun', '--file', 'a.txt', '-n', '5', '--flag', '--name=bob'];
var o = ParseOptions(m);
?. o.file;
?. o.n;
?. o.flag;
?. o.name;
