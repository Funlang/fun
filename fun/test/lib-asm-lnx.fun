// lib-asm on Linux x86_64: `#!asm` bodies run from libc mmap'd memory and must
// use the System V AMD64 convention (arguments in rdi/rsi/rdx..., return in
// rax), unlike the Win32 stack form. Linux counterpart of the Win32 example
// fun/demos/benchmarks/test-lib-asm-fun-9-2.fun.
// Host-dependent: needs libc mmap; the snapshot is only valid on Linux x86_64.
use 'fun/lib/lib-asm-pro.fun';

// 1) Pure register math: Run(n) = 2n.
var dbl = Assembly('i:i', `#!asm
mov rax, rdi
add rax, rax
ret
`);
dbl.Load();
?. dbl.Run(0);
?. dbl.Run(21);
?. dbl.Run(-3);

// 2) Call back into Fun. cb(a, b) = a * 10 + b; the incoming rdi is the first
//    argument, and <cb> embeds the 64-bit callback address (mov r64, imm64).
fun cb(a, b)
  result = a * 10 + b;
end fun;
var p = cb.@toCallback(nil, 'ii:i', true);
var j = Assembly('i:i', `#!asm
push rdi
mov esi, $00000002
mov rax, <cb>
call eax
pop rdi
ret
`, [cb: p]);
j.Load();
?. j.Run(21);
?. j.Run(3);

// 3) Two callbacks: 11 + 22 = 33. The partial result survives the second call
//    because it is kept in rbx (callee-saved), not rdx (caller-saved).
fun inc1(a) result = a + 1; end fun;
fun inc2(a) result = a + 2; end fun;
var q = Assembly('i:i', `#!asm
push rdi
push rbx
mov edi, $0000000A
mov rax, <c1>
call eax
mov rbx, rax
mov edi, $00000014
mov rax, <c2>
call eax
add rbx, rax
mov rax, rbx
pop rbx
pop rdi
ret
`, [c1: inc1.@toCallback(nil, 'i:i', true), c2: inc2.@toCallback(nil, 'i:i', true)]);
q.Load();
?. q.Run(0);

// 4) A body without `ret` gets a plain one appended (no Win32 `ret n`).
var t = Assembly('i:i', `#!asm
mov rax, rdi
add rax, rax
`);
t.Load();
?. t.Run(9);

dbl.Delete();
j.Delete();
q.Delete();
t.Delete();
?. 'ok';
