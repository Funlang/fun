// lib-proc on Linux: ProcList reads /proc, SearchMem scans /proc/<pid>/mem.
// Host-dependent (Linux /proc backend).
use 'fun/lib/lib-proc-lnx.fun';

var getpid = 'libc.so.6'.getapi('getpid', ':i');
var pid = getpid.call();

// process listing
var ps = proc.ProcList(true);
?. ps.@count() > 0;
var has1 = false;
for p in ps do
  if p.pid = 1 then has1 = true; end if;
end do;
?. has1;

// filter by short name, then full path (the filter runs on the short name)
var me = proc.ProcList(false, ['funcmd'], nil);
?. me.@count() > 0;
var mef = proc.ProcList(true, ['funcmd'], nil);
?. mef.@count() > 0;
?. (mef[0].exe =~ /funcmd$/) <> nil;
?. mef[0].exe.length() >= 6;

// regex filter (exeLike)
?. proc.ProcList(false, nil, /^funcmd$/).@count() > 0;

// memory scan of our own address space
var m = proc.SearchMem(pid, /lib-proc/, 0, false);
?. m <> nil;
?. m.@@();
var all = proc.SearchMem(pid, /funcmd/, 0, true);
?. all <> nil;
?. all.@count() > 0;
