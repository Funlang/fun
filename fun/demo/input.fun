########################################
# input
########################################
# Read a Chinese question and answer it with a few regex rewrites.  The verb
# reduplication is matched by structure, not by a hard-coded word list:
#
#   A不A   -> A       会不会->会, 能不能->能, 是不是->是, 好不好->好, ...
#   你<->我           双向人称代词替换
#   (吗)?  -> !       疑问句尾(有 吗 就吃掉 吗, 没有就只换问号)
#
#   Q: 你会聊天吗?     A: 我会聊天!
#   Q: 你能不能帮我?   A: 我能帮你!
#
# The callback form of replace() is what makes the pronoun swap one pass and
# bidirectional (你->我 and 我->你 at once, without a second pass seeing the
# first pass's output).
#
# The bundled PCRE is built without UTF-8 support, so the patterns work on
# bytes: a CJK character is three bytes, hence the three '.' in the group.
#
# 'line'.input(prompt, ok: ok) reads one line.  ok is false at end of input
# (Ctrl-D / EOF), the only reliable stop condition: Fun compares '' and nil
# as equal, so a blank line would otherwise look like end of input.
#
# Interactively:        funcmd fun/demo/input.fun
# From a pipe:          printf '你会聊天吗?\n' | funcmd fun/demo/input.fun

fun swap(s)
  if s = '你' then result = '我'; else result = '你'; end if;
end fun;

fun reply(q)
  result = q.replace(/(...)不\1/g, '$1');                   # A不A -> A
  result = result.replace(/你|我/g, (m){@= swap(m.value())}); # 你<->我
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
