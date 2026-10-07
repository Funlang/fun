// lib-asm on Linux x86_64 with the x86-64 forms added to asm-list.fd in D24.
//
// `lib-asm-lnx.fun` proves the assembler path works; this one exercises the
// table entries that were missing before (REX registers, callee-saved
// push/pop, rbp frames, disp8 locals, RIP-relative lea) using System V AMD64
// (rdi/rsi -> rax).
//
// Host-dependent: needs libc mmap. Displacements are written as the
// two's-complement byte with an explicit sign (`[rbp+FC]` = [rbp-4]): the key
// only records how many digits the operand has, and a leading '-' (as in
// `[rbp-1]`) makes Compile() two's-complement it again.
use 'fun/lib/lib-asm-pro.fun';

// f(a, b) = 2*b + a with a real prologue/epilogue: rbp frame, a disp8 local,
// and r12 (callee-saved, restored).
var f = Assembly('ii:i', `#!asm
push rbp
mov rbp, rsp
push r12
sub rsp, 10
mov dword ptr [rbp+FC], edi
mov r12, rsi
mov rax, r12
add rax, rax
add eax, dword ptr [rbp+FC]
add rsp, 10
pop r12
pop rbp
ret
`);
f.Load();
?. f.Run(3, 4);
?. f.Run(-1, 5);
?. f.Run(0, 0);

// g(n) = 2n through r8, plus a RIP-relative lea (its target is unused).
var g = Assembly('i:i', `#!asm
mov r8, rdi
add r8, r8
mov rax, r8
xor r8d, r8d
lea rdx, [rip+00000000]
ret
`);
g.Load();
?. g.Run(0);
?. g.Run(21);
?. g.Run(-3);
