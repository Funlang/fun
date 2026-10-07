// JSON \uHHHH decoding (libase esc()): a non-Unicode build must turn the escape
// text into real UTF-8, otherwise the same logical string is stored two ways
// depending on whether the client escaped non-ASCII (Python/Java do, browsers
// do not). Assertions compare decoded escapes with raw literals so the test
// holds on both the UTF-8 (Linux/FPC) and UTF-16 (Windows/Delphi) builds.
?. '@ascii  ' & ('' & ('{"a":"\u0041b"}'.getJson(json: true).a = 'Ab'));
?. '@cjk    ' & ('' & ('{"a":"\u4e2d\u6587abc"}'.getJson(json: true).a = '中文abc'));
?. '@surrog ' & ('' & ('{"e":"\uD83D\uDE00"}'.getJson(json: true).e = '😀'));
?. '@tab    ' & ('' & ('{"t":"x\ty"}'.getJson(json: true).t = ('x' & 9.toChar() & 'y')));
?. '@quote  ' & ('' & ('{"q":"a\"b"}'.getJson(json: true).q = 'a"b'));
