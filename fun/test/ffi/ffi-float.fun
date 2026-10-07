
########################################
# Linux FFI: float and mixed double/int args
########################################
# Float args/returns use ffi_type_float (SSE single-precision).
# Run from the repo root:
#   src/prj/fun/funcmd fun/test/ffi/ffi-float.fun
########################################

var fsumf  = './fun/test/ffi/libffitest.so'.getapi('fsum', 'ff:f');
var fdblf  = './fun/test/ffi/libffitest.so'.getapi('fdbl', 'f:f');
var dfromf = './fun/test/ffi/libffitest.so'.getapi('dfromf', 'f:d');
var mixsum = './fun/test/ffi/libffitest.so'.getapi('mixsum', 'idi:d');
var fivef  = './fun/test/ffi/libffitest.so'.getapi('five', ':d');
var identf = './fun/test/ffi/libffitest.so'.getapi('ident', 'd:d');

?. fsumf(1.5, 2.25); ?. ' <- fsum(1.5,2.25) expect 3.75';
?. fdblf(2.5);       ?. ' <- fdbl(2.5) expect 5';
?. dfromf(3.0);      ?. ' <- dfromf(3) double-from-float expect 6';
?. mixsum(2, 1.5, 3); ?. ' <- mixsum(2,1.5,3) expect 6.5';
?. fivef();          ?. ' <- five() expect 5';
?. identf(7.5);      ?. ' <- ident(7.5) expect 7.5';
