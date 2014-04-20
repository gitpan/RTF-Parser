package RTF::TEXT::Converter::charmap;
$RTF::TEXT::Converter::charmap::VERSION = '1.12';
use strict;
use warnings;

my @data = (<DATA>);
chomp(@data);

sub data {

    return @data;

}

1;

__DATA__
exclam		!
quotedbl	"
numbersign	#
dollar		$
percent		%
ampersand	&amp;
quoteright	'
parenleft	(
parenright	)
asterisk	*
plus		+
comma		,
hyphen		-
period		.
slash		/
zero		0
one		1
two		2
three		3
four		4
five		5
six		6
seven		7
eight		8
nine		9
colon		:
semicolon	;
less		&lt;
equal		=
greater		&gt;
question	?
at		@
bracketleft	[
backslash	\
bracketright	]
asciicircum	^
underscore	_
quoteleft	`
braceleft	{
bar		|
braceright	}
asciitilde	~
OE		OE
acute		'
angleleft	[
angleright	&gt;
approxequal	~
arrowboth	&lt;-&gt; 
arrowdblboth	&lt;=&gt; 
arrowdblleft	&lt;=
arrowdblright	=&gt;
arrowleft	&lt;-
arrowright	-&gt;
bullet		*    
cent		&#162;
circumflex	^
copyright	&#169;
copyrightsans	&#169;
dagger		+    
degree		&#176;
delta		d    
divide		&#247;
dotlessi	i    
ellipsis	...
emdash		--   
endash		-    
fi		fi   
fl		fl   
fraction	/
grave		`
greaterequal	&gt;=
guillemotleft	&#171;
guillemotright	&#187;
guilsinglleft	&lt;
guilsinglright	&gt;
lessequal	&lt;=
logicalnot	&#172;
mathasterisk	*
mathequal	=
mathminus	-
mathnumbersign	#
mathplus	+
mathtilde	~
minus		-
mu		&#181;
multiply	&#215;
nobrkhyphen	-
nobrkspace	&#160;
notequal	!=
oe		oe
onehalf		&#189;
onequarter	&#188;
periodcentered	.
plusminus	&#177;
quotedblbase	,,
quotedblleft	"
quotedblright	"
quotesinglbase	,
registered	&#174;
registersans	&#174;
threequarters	&#190;
tilde		~
trademark	[tm]
AE		&AElig;
Aacute      &Aacute;
Acircumflex &Acirc;
Agrave      &Agrave;
Aring       &Aring;
Atilde		&#195;
Adieresis	&Auml;
Ccedilla	&Ccedil;
Eth		&#208;
Eacute	&Eacute;
Ecircumflex	&Ecirc;
Egrave	&Egrave;
Edieresis	&Euml;
Iacute	&Iacute;
Icircumflex	&Icirc;
Igrave	&Igrave;
Idieresis	&Iuml;
Ntilde	&Ntilde;
Oacute	&Oacute;
Ocircumflex	&Ocirc;
Ograve	&Ograve;
Oslash	&Oslash;
Otilde	&#213;
Odieresis	&Ouml;
Thorn	&#222;
Uacute	&Uacute;
Ucircumflex	&Ucirc;
Ugrave	&Ugrave;
Udieresis	&Uuml;
Yacute	&#221;
ae		&aelig;
aacute	&aacute;
acircumflex	&acirc;
agrave	&agrave;
aring	&aring;
atilde	&atilde;
adieresis	&auml;
ccedilla	&ccedil;
eacute	&eacute;
ecircumflex	&ecirc;
egrave	&egrave;
eth	&#240;
edieresis	&euml;
iacute	&iacute;
icircumflex	&icirc;
igrave	&igrave;
idieresis	&iuml;
ntilde	&ntilde;
oacute	&oacute;
ocircumflex	&ocirc;
ograve	&ograve;
oslash	&oslash;
otilde	&otilde;
odieresis	&ouml;
germandbls	&szlig;
thorn	&#254;
uacute	&uacute;
ucircumflex	&ucirc;
ugrave	&ugrave;
udieresis	&uuml;
yacute	&yacute;
ydieresis	&yuml;
newline	<br>
ordfeminine     &#170;
ordmasculine    &#186;
questiondown    &#191;
exclamdown      &#161;
section         &#167;
onesuperior     &#185;
twosuperior     &#178;
threesuperior   &#179;
sterling        &#163;
currency        &#164;
yen             &#165;
brokenbar       &#166;
dieresis        &#168;
opthyphen       &#173;
macron          &#175;
paragraph       &#182;
cedilla         &#184;
