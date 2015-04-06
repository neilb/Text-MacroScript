#!/usr/bin/perl -w

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Test::More;

my $ms;

use_ok 'Text::MacroScript';

#------------------------------------------------------------------------------
# define
$ms = new_ok('Text::MacroScript' => [ 
				-macro => [ 
					[ "hello" => "Hallo" ],
					[ "world" => "Welt" ],
				]]);
$ms->define( -macro => "NUM" => "25" );
is $ms->expand("\n"), 		"\n";
is $ms->expand("helloNUMnumworld\n"), 	"Hallo25numWelt\n";
is $ms->expand("%DEFINE ZZ [zx]\n"), 		"";
is $ms->expand("%DEFINE zx [spectrum]\n"),"";
is $ms->expand("hello ZZ\n"), 			"Hallo spectrum\n";
is $ms->expand("%DEFINE Z1 [hel]\n"),	"";
is $ms->expand("%DEFINE Z2 [lo]\n"),	"";
is $ms->expand("%DEFINE EVAL [#0]\n"),	"";
is $ms->expand("Z1\n"),	 				"hel\n";
is $ms->expand("EVAL[Z1]\n"),			"hel\n";
is $ms->expand("Z1Z2\n"),	 			"hello\n";
# Bug #1: expansion depends on size of macro name
#is $ms->expand("EVAL[Z1Z2]\n"),			"Hallo\n";

#------------------------------------------------------------------------------
# Bug #1: expansion depends on size of macro name
$ms = new_ok('Text::MacroScript' => [ 
				-macro => [ 
					[ "hello"	=> "Hallo" ],
					[ "Z1"		=> "hel" ],
					[ "Z2"		=> "lo" ],
				]]);
is $ms->expand("hello Z1 Z2\n"),	 	"Hallo hel lo\n";
#is $ms->expand("Z1Z2\n"),	 			"Hallo\n";
$ms = new_ok('Text::MacroScript' => [ 
				-macro => [ 
					[ "ZZZZZ1"	=> "hel" ],
					[ "ZZZZZ2"	=> "lo" ],
					[ "hello"	=> "Hallo" ],
				]]);
is $ms->expand("hello ZZZZZ1 ZZZZZ2\n"),"Hallo hel lo\n";
is $ms->expand("ZZZZZ1ZZZZZ2\n"),		"Hallo\n";

#------------------------------------------------------------------------------
# undefine
$ms = new_ok('Text::MacroScript');
$ms->define( -macro => "NUM", 25 );
is $ms->expand("NUMNUM"), 			"2525";
# Enhancement #4: undefine_all() should carp if no option is given
# $ms->undefine();
$ms->undefine( -macro => "NUM" );
is $ms->expand("NUMNUM"), 			"NUMNUM";
# Enhancement #2: expand() does not accept a multi-line text
#is $ms->expand("%DEFINE N [nn]\nNN\n%UNDEFINE N\nNN\n"), "nnnn\nNN\n";
is $ms->expand("%DEFINE N [nn]\n"),	"";
is $ms->expand("NN\n"), 			"nnnn\n";
is $ms->expand("%UNDEFINE N\n"), 	"";
is $ms->expand("NN\n"), 			"NN\n";

#------------------------------------------------------------------------------
# undefine_all
$ms = new_ok('Text::MacroScript');
$ms->define( -macro => "N1", 1 );
$ms->define( -macro => "N2", 2 );
$ms->define( -macro => "N3", 3 );
is $ms->expand("N1N2N3"), "123";
$ms->undefine_all('-macro');
is $ms->expand("N1N2N3"), "N1N2N3";

is $ms->expand("%DEFINE N1 [1]"), "";
is $ms->expand("%DEFINE N2 [2]"), "";
is $ms->expand("%DEFINE N3 [3]"), "";
is $ms->expand("N1N2N3"), "123";
is $ms->expand("%UNDEFINE_ALL"), "";
is $ms->expand("N1N2N3"), "N1N2N3";

#------------------------------------------------------------------------------
# macros with regexp-special-chars
$ms = new_ok('Text::MacroScript');
is $ms->expand("%DEFINE * [star]\n"),"";
is $ms->expand("2*4\n"),			"2star4\n";

#------------------------------------------------------------------------------
# macros with arguments
$ms = new_ok('Text::MacroScript');
# Bug #3: Cannot catch error "missing parameter or unescaped # in MACRO"
#is $ms->expand("%DEFINE * [#0+#1+#2+#3+#4+#5+#6+#7+#8+#9+#10]\n"),	"";
#eval {$ms->expand("*\n")};
#like $@, qr/missing or unescaped \# in MACRO/;
is $ms->expand("%DEFINE * [#0+#1]\n"),	"";
is $ms->expand("*[0|1]\n"),				"0+1\n";
is $ms->expand("*[ 0 | 1 ]\n"),			" 0 + 1 \n";
is $ms->expand("*[0|1|2]\n"),			"0+1\n";

is $ms->expand("%DEFINE * [#0+\#ffff]\n"),	"";
is $ms->expand("*[1]\n"),				"1+#ffff\n";

#------------------------------------------------------------------------------
# multi-line define
$ms = new_ok('Text::MacroScript');
is $ms->expand("%DEFINE *\n"),			"";
is $ms->expand("line 1: #0\n"),			"";
is $ms->expand("line 2: #1\n"),			"";
is $ms->expand("line 3: #2\n"),			"";
is $ms->expand("%END_DEFINE\n"),		"";
is $ms->expand("*[a|b|c]\n"),			"line 1: a\nline 2: b\nline 3: c\n\n";

done_testing;
