// getapi() with a raw numeric address ('' library + address as the name arg).
//
// The address comes from @toCallback(..., ptr: true), which is a heap-allocated
// libffi closure entry -> a high (>4GB) address on x86_64. Before the pointer
// widths were fixed, getapi truncated it to 32 bits and the call crashed.
fun myadd(a, b)
  result = a + b;
end fun;

var addr = myadd.@toCallback(nil, 'ii:i', ptr: true);
?. addr > 0;
var f = ''.getapi(addr, 'ii:i');
?. f(20, 22);
?. f(-5, 12);

// the normal (non-raw) callback path, for comparison: apply1(x, cb) = cb(x)
fun dbl(n)
  result = n * 2;
end fun;
var g = dbl.@toCallback(nil, 'i:i');
var apply = './fun/test/ffi/libffitest.so'.getapi('apply1', 'ic:i');
?. apply(5, g);
