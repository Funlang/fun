// lib-asm-a64 on Linux: pure text -> machine-code encodings of the aarch64
// backend, plus (on an aarch64 host) one live JIT call to prove the mmap path
// and the icache flush work.
//
// The encoder is host-independent string/number work, so the snapshot is
// generated on any host (the CI host is x86_64); only the final "exec" line
// depends on the cpu and reads "skip" off aarch64. Host-dependent: needs the
// FFI/mmaps that lib-asm itself needs.
//
// AArch64 byte encodings here were cross-checked against the keystone/gas
// assembler for the same instructions (see fun/test/tools/asm-a64-diff.sh for
// the gcc-aarch64-linux-gnu-as + objdump route when that toolchain exists).
use 'fun/lib/lib-asm-a64.fun';

var cpu = 'host'.arg().getJson(fd: true).cpu;

// Compile one `#!asm` body and print its hex. A direct AssemblyA64 instance is
// used so this runs on any host: Load() (the only arch-gated entry) is never
// called here.
var enc = AssemblyA64('i:i', '', nil);
fun show(name, body)
  ?. name & ': ' & enc.Compile(body);
end fun;

show('addsub_imm', `#!asm
add x0, x1, #1
add x2, x3, #4096
sub x4, x5, #8
subs x6, x7, #16
cmp x8, #7
`);

show('addsub_reg', `#!asm
add x0, x1, x2
add x3, x4, x5, lsl #3
subs x6, x7, x8
neg x9, x10
cmp x11, x12
`);

show('logic_reg', `#!asm
and x0, x1, x2
orr x3, x4, x5
eor x6, x7, x8
ands x9, x10, x11
tst x12, x13
mvn x14, x15
`);

show('logic_imm', `#!asm
and x0, x0, #0xff
orr x1, x1, #0xf
eor x2, x2, #0xff00
ands x3, x3, #0xffff
orr w4, w4, #0xf0
and w7, w7, #1
and x5, x5, #0xffff0000
orr x6, xzr, #0xffffffff
`);

show('movwide', `#!asm
movz x0, #0x1234
movz x1, #0x1234, lsl #16
movk x2, #0xabcd, lsl #48
movn x3, #0xff
movk w4, #0x1234, lsl #16
`);

show('mov_reg', `#!asm
mov x0, x1
mov w2, w3
mov x4, sp
mov sp, x5
mov w6, wsp
`);

show('mov_imm', `#!asm
mov x0, #0
mov x1, #0xffff
mov x2, #0x10000
mov x3, #0xff00ff00
mov x4, #0x12345678
mov x5, #0xffffffff
mov w6, #0xffffff00
`);

show('csel', `#!asm
csel x0, x1, x2, eq
csel x3, x4, x5, gt
csel w6, w7, w8, lt
`);

show('loadstore', `#!asm
ldr x0, [x1]
ldr x0, [x1, #8]
str w0, [x1, #4]
ldrb w0, [x1, #3]
strb w0, [x1, #2]!
ldr x1, [x1], #8
ldr x2, [x3, x4, lsl #3]
`);

show('pair', `#!asm
stp x29, x30, [sp, #-16]!
ldp x29, x30, [sp], #16
stp x0, x1, [x2, #16]
ldp w0, w1, [sp]
`);

show('branch', `#!asm
mov x1, x0
mov x0, #0
loop:
add x0, x0, x1
subs x1, x1, #1
b.ne loop
ret
`);

show('misc', `#!asm
nop
br x9
blr x9
ret
`);

show('sum1ton', `#!asm
@sum1ton
`);

// `<name>` callback: address is host-specific, so only assert it encoded.
fun cb(a)
  result = a + 1;
end fun;
var named = AssemblyA64('i:i', '', [cb: cb.@toCallback(nil, 'i:i', true)]);
var ch = named.Compile(`#!asm
mov x9, <cb>
blr x9
ret
`);
?. 'callback: ' & ((ch.length() > 0) and 'encoded' or 'EMPTY');

// Live execution only where the backend can run.
if cpu = 'arch64' then
  Assembly = AssemblyA64();
  var dbl = Assembly('i:i', `#!asm
add x0, x0, x0
ret
`);
  dbl.Load();
  ?. 'exec: ' & dbl.Run(21);
  dbl.Delete();
else
  ?. 'exec: skip (cpu=' & cpu & ')';
end if;

?. 'ok';
