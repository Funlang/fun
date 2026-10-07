// lib-jit: NewJit dispatch (#!c -> TCC, otherwise inline assembly).
// On Linux only the C path is exercisable: the assembly backend allocates
// executable memory via kernel32.VirtualAlloc. Host-dependent: needs
// libtcc.so next to funcmd (make-linux-x86_64.sh builds it from src/3rd/tcc).
use 'fun/lib/lib-jit.fun';

var jit = NewJit(`#!C ii:i
  int sum(int n) { long long s = 0; for (int i = 1; i <= n; i++) s += i; return (int)s; }
`);
?. jit.call(100);
?. jit.call(1000);
jit.del();

var jit2 = NewJit(`#!C ic:i
  int sum2(int n, int (*t)(int, int)) { long long s = 0; for (int i = 1; i <= n; i++) s += t(i, 2); return (int)s; }
`);
fun dbl(x, y)
  result = x * y;
end fun;
?. jit2.call(5, dbl.@toCallback(nil, 'ii:C', true));
jit2.del();

? 'ok';
