########################################
# input
########################################
# Read a Chinese question and answer it with a few plain regex rewrites:
#
#   你      -> 我
#   会不会  -> 会
#   能不能  -> 能
#   吗?     -> !
#
#   Q: 你会聊天吗?
#   A: 我会聊天!
#
# 'line'.input(prompt, ok: ok) reads one line.  ok is false at end of input
# (Ctrl-D / EOF), the only reliable stop condition: Fun compares '' and nil
# as equal, so a blank line would otherwise look like end of input.
#
# Interactively:        funcmd fun/demo/input.fun
# From a pipe:          printf '你会聊天吗?\n' | funcmd fun/demo/input.fun

fun reply(q)
  result = q.replace(/会不会/g, '会');
  result = result.replace(/能不能/g, '能');
  result = result.replace(/吗\?/g, '!');
  result = result.replace(/你/g, '我');
end fun;

?. 'Ask me anything.  End with Ctrl-D.';

var ok;
var q = 'line'.input('Q: ', ok: ok);

while ok do
  ?. 'A: ' & reply(q);
  q = 'line'.input('Q: ', ok: ok);
end do;

?. 'Bye.';
