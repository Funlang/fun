var ok;
var c = 'char'.input(ok: ok);
while ok do
  ?. '[' & c & ']';
  c = 'char'.input(ok: ok);
end do;
?. 'char-eof';
