// Probe 2: is the interpreter safe when TWO threads evaluate Fun at once?
//
// FPC's default memory manager is not thread-safe unless the cthreads unit is
// linked (-dUseCThreads). funcmd is built without it, so concurrent heap use
// from a pthread and the main thread is the risk we want to measure, not just
// "can a single foreign thread call back".
use 'fun/lib/lib-utils.fun';

var _pthread_create = 'libpthread.so.0'.getapi('pthread_create', 'pppp:i');
var _pthread_join   = 'libpthread.so.0'.getapi('pthread_join',   'pp:i');
var _usleep         = 'libc.so.6'.getapi('usleep', 'i:');

var N = 200000;
var workerSum = 0;
var mainSum   = 0;

fun spinglobal(n)
  var s = '';
  for i = 1 to n do
    s = 'x' & i;
  end do;
  workerSum += s.length();
  result = 0;
end fun;

fun mainspin(n)
  var s = '';
  for i = 1 to n do
    s = 'y' & i & 'z';
  end do;
  mainSum += s.length();
end fun;

var tid = 0.toChar().x(8);
var fn  = spinglobal.@toCallback(nil, 'i:i', ptr: true);
var rc  = _pthread_create(tid.toNum(-1), 0, fn, N);
?. 'create rc =' & rc;

// Main thread hammers the heap at the same time.
mainspin(N);
// give the worker time to finish; no join (str2int cannot read a full pthread_t)
_usleep(2000000);
?. 'both done, workerSum =' & workerSum & ', mainSum =' & mainSum;
