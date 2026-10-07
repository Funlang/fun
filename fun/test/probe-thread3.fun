// Probe 3: a SINGLE worker thread evaluates while the main thread only sleeps
// (no concurrent evaluation). This is the "background server thread" shape:
// if it survives, a worker can own evaluation as long as main stays out.
use 'fun/lib/lib-utils.fun';

var _pthread_create = 'libpthread.so.0'.getapi('pthread_create', 'pppp:i');
var _pthread_join   = 'libpthread.so.0'.getapi('pthread_join',   'pp:i');
var _usleep         = 'libc.so.6'.getapi('usleep', 'i:');

var N = 300000;
var workerSum = 0;

fun spinglobal(n)
  var s = '';
  for i = 1 to n do
    s = 'x' & i;
  end do;
  workerSum += s.length();
  result = 0;
end fun;

var tid = 0.toChar().x(8);
var fn  = spinglobal.@toCallback(nil, 'i:i', ptr: true);
var rc  = _pthread_create(tid.toNum(-1), 0, fn, N);
?. 'create rc =' & rc;
// main does NOT evaluate; it just waits.
_usleep(3000000);
// no pthread_join: reading a 64-bit pthread_t out of a Fun string needs the full
// 8 bytes and str2int() only reads 4; the join call itself was segfaulting.
?. 'main done waiting, workerSum =' & workerSum;
