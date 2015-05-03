#!/usr/bin/perl

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
				-variable => [ 
					[ N1 => 1 ],
					[ N2 => 2 ],
				],
				-script => [ 
					[ ADD => '#0+#1' ],
				]]);
$ms->define( -variable => N3 => 3 );
$ms->define( -script => SUM => 'my $s=0;for(@Param){$s+=$_};$s' );
is $ms->expand("N1 #N1 N2 #N2 N3 #N3"),	"N1 #N1 N2 #N2 N3 #N3";

is $ms->expand("%DEFINE_SCRIPT SHOW\n"),	"";
is $ms->expand("join(',', \@Param, #N1||0, #N2||0, #N3||0, ".
			   "\$Var{N1}||0, \$Var{N2}||0, \$Var{N3}||0 )\n"),	"";
is $ms->expand("%END_DEFINE\n"),			"";
is $ms->expand("SHOW\n"),					"1,2,3,1,2,3\n";
is $ms->expand("SHOW[4]\n"),				"4,1,2,3,1,2,3\n";
is $ms->expand("SHOW[4|5]\n"),				"4,5,1,2,3,1,2,3\n";
$ms->undefine(-variable => "N3");
is $ms->expand("SHOW\n"),					"1,2,0,1,2,0\n";
is $ms->expand("%UNDEFINE_VARIABLE N2"), "";
is $ms->expand("SHOW\n"),					"1,0,0,1,0,0\n";
is $ms->expand("%DEFINE_VARIABLE N2[2]"), "";
is $ms->expand("%DEFINE_VARIABLE N3[3]"), "";
is $ms->expand("SHOW\n"),					"1,2,3,1,2,3\n";
diag 'Issue #6: %UNDEFINE_ALL_VARIABLE does not work';
#is $ms->expand("%UNDEFINE_ALL_VARIABLE"), "";
#is $ms->expand("SHOW\n"),					"0,0,0,0,0,0\n";
$ms->define( -variable => N1 => 4 );
$ms->define( -variable => N2 => 5 );
$ms->define( -variable => N3 => 6 );
is $ms->expand("SHOW\n"),					"4,5,6,4,5,6\n";
$ms->undefine_all(-variable);
is $ms->expand("SHOW\n"),					"0,0,0,0,0,0\n";

#------------------------------------------------------------------------------
# undefine
is $ms->expand("ADD[1|3]"),	"4";
$ms->undefine(-script => "ADD");
is $ms->expand("ADD[1|3]"),	"ADD[1|3]";

diag 'Issue #5: Syntax SUM[] should be accepted to call script without parameters';
#is $ms->expand("SUM[]"),	"0";
is $ms->expand("SUM"),	"0";
is $ms->expand("SUM[1]"),	"1";
is $ms->expand("SUM[1|2]"),	"3";
is $ms->expand("SUM[1|2|3]"),"6";
is $ms->expand("%UNDEFINE_SCRIPT SUM\n"), "";
is $ms->expand("SUM"),	"SUM";

#------------------------------------------------------------------------------
# undefine_all
$ms->define(-script => S1 => 1);
$ms->define(-script => S2 => 2);
$ms->define(-script => S3 => 3);
is $ms->expand("S1S2S3"),	"123";
$ms->undefine_all('-script');
is $ms->expand("S1S2S3"),	"S1S2S3";

$ms->define(-script => S1 => 1);
$ms->define(-script => S2 => 2);
$ms->define(-script => S3 => 3);
is $ms->expand("S1S2S3"),	"123";
is $ms->expand("%UNDEFINE_ALL_SCRIPT\n"),	"";
is $ms->expand("S1S2S3"),	"S1S2S3";

#------------------------------------------------------------------------------
# scripts with regexp-special-chars
$ms = new_ok('Text::MacroScript');
is $ms->expand("%DEFINE_SCRIPT * ['*']\n"),"";
is $ms->expand("2*4\n"),			"2*4\n";

#------------------------------------------------------------------------------
# escape # inside script
$ms = new_ok('Text::MacroScript');
is $ms->expand("%DEFINE_SCRIPT * ['\\#0']\n"),"";
is $ms->expand("2*4\n"),			"2#04\n";

#------------------------------------------------------------------------------
diag 'Issue #7: expansion depends on size of script name';
$ms = new_ok('Text::MacroScript' => [ 
				-script => [ 
					[ "hello"	=> "'Hallo'" ],
					[ "Z1"		=> "'hel'" ],
					[ "Z2"		=> "'lo'" ],
				]]);
is $ms->expand("hello Z1 Z2\n"),	 	"Hallo hel lo\n";
#is $ms->expand("Z1Z2\n"),	 			"Hallo\n";
$ms = new_ok('Text::MacroScript' => [ 
				-script => [ 
					[ "ZZZZZ1"	=> "'hel'" ],
					[ "ZZZZZ2"	=> "'lo'" ],
					[ "hello"	=> "'Hallo'" ],
				]]);
is $ms->expand("hello ZZZZZ1 ZZZZZ2\n"),"Hallo hel lo\n";
is $ms->expand("ZZZZZ1ZZZZZ2\n"),		"Hallo\n";

#------------------------------------------------------------------------------
# expand variables in scripts
diag 'Issue #37: Variables should be expanded in all input text, not only in macro scripts';
$ms = new_ok('Text::MacroScript');
$ms->define_variable(YEAR => 2015);
$ms->define(-script => SHOW => '"\\#YEAR = #YEAR"');
#is $ms->expand("SHOW"), "#YEAR = 2015";


done_testing;
