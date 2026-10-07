'defaultCodePage'.set(65001);
var ok = true;
var q = '';
loop
  exit when not ok or q = '';
  ?. 'inside';
end loop;
?. 'done';
