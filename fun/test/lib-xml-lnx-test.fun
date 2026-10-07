// lib-xml-lnx on libxml2: structure, attributes, text, CDATA/entities, file
// load, and the each() walker.
use 'fun/lib/lib-xml-lnx.fun';

var d = XmlDocument();
?. 'load=' & d.load('<root a="1" b="two"><child x="10">hello</child><child x="20"/><empty/></root>');
var j = d.toJson();
?. 'root=' & j.@ & ' a=' & j.a & ' b=' & j.b;
var cs = j.$;
?. 'children=' & cs.@count();
for c in cs do
  ?. ' child=' & c.@ & ' x=' & (c.x or 'nil') & ' kids=' & (c.$ and c.$.@count() or 0);
end do;
var c0 = cs[0];
var c0k = c0.$;
?. 'text node=' & c0k[0].@ & ' text=' & c0k[0].text;

// CDATA + entities + nesting
?. 'load2=' & d.load('<a><b><c>deep</c></b><d><![CDATA[<raw & stuff>]]></d><e>a&amp;b&lt;c</e></a>');
var j2 = d.toJson();
var b = j2.$[0];
var bc = b.$[0];
?. 'nested=' & b.@ & '.' & bc.@ & '=' & bc.$[0].text;
var dd = j2.$[1];
?. 'cdata=' & dd.$[0].text;
var ee = j2.$[2];
?. 'entity=' & ee.$[0].text;

// file load (path vs literal heuristic)
var f = '/tmp/fun-xml-lnx-test.xml';
var w = '<cfg mode="fast"><n>3</n></cfg>';
f.save(w);
var d2 = XmlDocument();
?. 'file load=' & d2.load(f);
var jf = d2.toJson();
?. 'file root=' & jf.@ & ' mode=' & jf.mode;
f.move();

// each walker
var d3 = XmlDocument();
d3.load('<r><p><q/></p><s/></r>');
var names = '';
d3.each((doc, node, kids){
  names &= node.@ & ',';
  kids(0);
});
?. 'walk=' & names;

// malformed input raises
var bad = false;
try d3.load('<a><b></a>'); except bad = true; end try;
?. 'malformed raised=' & bad;
