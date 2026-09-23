########################################
# input
########################################
# Read a Chinese question and answer it with a few regex rewrites.  The verb
# reduplication is matched by structure, not by a hard-coded word list:
#
#   A不A   -> A       会不会->会, 能不能->能, 是不是->是, 好不好->好,
#                     可不可以->可以, 知不知道->知道, ...
#   你<->我           双向人称代词替换(一趟完成)
#   (吗)?  -> !       疑问句尾(有 吗 就吃掉 吗, 没有就只换问号)
#
#   Q: 你会聊天吗?     A: 我会聊天!
#   Q: 你能不能帮我?   A: 我能帮你!
#
# Notes:
#   - The bundled PCRE is built without UTF-8 support, so patterns work on
#     bytes.  `.{1,3}` matches one character whether it is ASCII (1 byte),
#     GBK (2 bytes) or UTF-8 CJK (3 bytes), so the same rule holds for either
#     encoding.
#   - The single-line replace callback is an arrow lambda, and its 你/我 swap
#     uses the `and`/`or` if-else idiom: `cond and a or b` yields a when cond
#     is true and b otherwise.
#
# 'line'.input(prompt, ok: ok) reads one line.  ok is false at end of input
# (Ctrl-D / EOF), the only reliable stop condition: Fun compares '' and nil
# as equal, so a blank line would otherwise look like end of input.
#
# Interactively:        funcmd fun/demo/input.fun
# From a pipe:          printf '你会聊天吗?\n' | funcmd fun/demo/input.fun

fun reply(q)
  result = q.replace(/(.{1,3})不\1/g, '$1');                  # A不A -> A
  result = result.replace(/你|我/g, m -> m.value() = '你' and '我' or '你');
  result = result.replace(/(吗)?\?/g, '!');                   # 疑问句尾 -> !
end fun;

?. 'Ask me anything.  End with Ctrl-D.';

var ok;
var q = 'line'.input('Q: ', ok: ok);

while ok do
  ?. 'A: ' & reply(q);
  q = 'line'.input('Q: ', ok: ok);
end do;

?. 'Bye.';
