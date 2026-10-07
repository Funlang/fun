// Probe 6: two threads running the SAME Fun function at once.
// Functions keep their locals in a per-environment variable stack; if that is
// shared, concurrent invocations of one function race. Compare with probe 2/4
// where distinct functions ran.
use 'fun/lib/lib-utils.fun';
var _pthread_create = 'libpthread.so.0'.getapi('pthread_create', 'pppp:i');
var _usleep         = 'libc.so.6'.getapi('usleep', 'i:');

var N = 200000;

fun work(idx)
  var s = '';
  var lst = new [];
  var sum = 0;
  for i = 1 to N do
    s = 'w' & idx & '-' & i;
    lst[i mod 64] = s.length();
    sum += s.length();
  end do;
  ?, 'worker' & idx & ' ok sum=' & sum;
  result = 0;
end fun;

var fn = work.@toCallback(nil, 'i:i', ptr: true);
var t1 = 0.toChar().x(8);
var t2 = 0.toChar().x(8);
_pthread_create(t1.toNum(-1), 0, fn, 1);
_pthread_create(t2.toNum(-1), 0, fn, 2);
?. 'created';
_usleep(4000000);
?. 'done';
