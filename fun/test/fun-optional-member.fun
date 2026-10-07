// Regression: an optional member (`x?.k?`) whose base is nil must yield nil,
// not the value found by an earlier call at the same AST node (the CId2.find
// stale-evar bug, fixed 2026-09-12).
fun f(a)
  result = a?.x?;
end fun;

?. f(new [x: 5]);
?. f(nil) = nil;
?. f(new [y: 9]) = nil;
?. f(new [x: 5]) = 5;
?. f(nil) = nil;
