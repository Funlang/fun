########################################
# input
########################################
# Read questions from the console and answer them: the reply is the question
# with its trailing '?' turned into '!'.
#
#   Q: Can you chat?
#   A: Can you chat!
#
# 'line'.input(prompt, ok: ok) reads one line.  ok is false at end of input
# (Ctrl-D / EOF), the only reliable stop condition: Fun compares '' and nil as
# equal, so a blank line would otherwise look like end of input.
#
# Interactively:        funcmd fun/demo/input.fun
# From a pipe:          printf 'Can you chat?\n' | funcmd fun/demo/input.fun

?. 'Ask me anything.  End with Ctrl-D.';

var ok;
var q = 'line'.input('Q: ', ok: ok);

while ok do
  var a = q;
  if (a.length() > 0) and (a[a.length() - 1] = '?') then
    a = a.substr(0, a.length() - 1) & '!';
  else
    a = a & '!';
  end if;
  ?. 'A: ' & a;
  q = 'line'.input('Q: ', ok: ok);
end do;

?. 'Bye.';
