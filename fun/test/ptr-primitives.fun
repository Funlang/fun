// Raw-pointer primitives on 32/64-bit targets.
// Guards the pointer-width chain: @count('ptr'), toNum(ptr:-1), .move(), .movs().
// These all broke on x86_64 before the pointer-wide reads were introduced
// (addresses were truncated to 32 bits).
use 'fun/lib/lib-utils.fun';
use 'fun/lib/lib-stack.fun';

// --- str2hex / hex2str: the buffer address comes from 'result.toNum(-1)' ---
?. str2hex('AB');
?. str2hex('Hello');
?. hex2str('414243');

// --- .movs(dest, len, pos, pod): receiver is the SOURCE, arg 1 is the dest ---
var d = 'xxxxx';
?. 'ABC'.movs(d, pos: 1);
?. d;
var e = 'hello world';
?. 'XYZ'.movs(e, len: 3, pod: 6);
?. e;

// --- Stack: CList address via @count('ptr') + manual word-size shift ---
var s = Stack();
var i;
for i = 0 to 9 loop s.push(i); end loop;
?. s.count();
?. s.peek(-4, true);
?. s.count();
var total = 0;
while not s.isEmpty() loop total += s.pop(); end loop;
?. total;
?. s.count();

// --- the address must actually sit above 4GB, otherwise this test would pass
// even with the old 32-bit truncation. Writes here go into a Fun string buffer,
// so nothing else is disturbed. ---
var buf = ' '.x(16);
var bp  = buf.toNum(-1);
?. bp > 4294967296;
'abcdefgh'.move(bp, 8);
?. buf.substr(len: 8);
