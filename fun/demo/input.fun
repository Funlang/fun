########################################
# input
########################################
#
#   一亿美金级 AI 代码,请勿轻易扩散,偷偷享用;
#   倘若有人问起,就说你只是随手敲了两行正则。
#
#   A hundred-million-dollar AI.  Do not spread it around; savor it in
#   silence.  If anyone asks, claim you just banged out a couple of regexes.
#
# Read a Chinese question and answer it with a few regex rewrites.  The verb
# reduplication is matched by structure, not by a hard-coded word list:
#
#   A(不|没)A -> A   会不会->会, 能不能->能, 是不是->是, 好不好->好,
#                    可不可以->可以, 知不知道->知道, 有没有->有, 去没去->去, ...
#   你/您/我          人称代词双向替换, 一趟完成(你,您->我; 我->你)
#   (吗|吧|呢)?      + 半角/全角问号 -> !
#
#   Q: 你会聊天吗?     A: 我会聊天!
#   Q: 你有没有钱?     A: 我有钱!
#
# Notes:
#   - The bundled PCRE is built without UTF-8 support, so patterns work on
#     bytes.  `.{1,3}` matches one character whether it is ASCII (1 byte),
#     GBK (2 bytes) or UTF-8 CJK (3 bytes).  Multi-byte literals must be
#     alternated, never put in a [...] class (a class would split their
#     bytes and misalign).
#   - The single-line replace callback is an arrow lambda; the 你/您/我 swap
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
  result = q.replace(/(.{1,3})(不|没)\1/g, '$1');           # A不A / A没A -> A
  result = result.replace(/你|我|您/g, m -> m.value() = '我' and '你' or '我');
  result = result.replace(/(吗|吧|呢)?(\?|？)/g, '!');       # 疑问句尾 -> !
end fun;

?. 'Ask me anything.  End with Ctrl-D.';

var ok;
var q = 'line'.input('Q: ', ok: ok);

while ok do
  ?. 'A: ' & reply(q);
  q = 'line'.input('Q: ', ok: ok);
end do;

?. 'Bye.';
