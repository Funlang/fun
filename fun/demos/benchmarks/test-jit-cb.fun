use 'lib-jit.fun';

# NOTE: the #!asm snippet below is 32-bit x86 (Windows) assembly.
# On Linux/ARM use the #!C path (portable) or rewrite the assembly for the target ABI.

var ii = 0;
fun cb(a, b)
  ii = a * 2^32 + b;
  ?, 'cb'; ?. ii;
  result = ii;
end fun;

# Assembly path (inline assembly, calls back into Fun)
var s = `#!asm i:i
    mov ecx, dword ptr [esp+04]
    @sum1ton
    push eax
    push edx
    mov  eax, <test>
    call eax
`;

var jit = NewJit(s, names: [test: cb.@toCallback(nil, 'ii:i', true)]);
?. jit.Run(100000000);
jit.Delete();
?. 'Ok';

# C path (runtime-compiled C via bundled TCC, calls back into Fun)
s = `#!C ii:i
  int sum(int n, int (*test)(int, int)) {
    long long s = 0;
    for(int i = 1; i <= n; i++) s += i;
    test((int)(s >> 32), (int)(s & 0xFFFFFFFF));
    return 1;
  }
`;

jit = NewJit(s);
?. jit.call(100000000, cb.@toCallback(nil, 'ii:C', true));
jit.del();
?. 'Ok';
