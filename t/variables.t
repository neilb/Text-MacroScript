#!/usr/bin/perl

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Capture::Tiny 'capture';
use Test::Differences;
use Test::More;

my $ms;
my($out,$err,@res);

sub void(&) { $_[0]->(); () }

use_ok 'Text::MacroScript';

#------------------------------------------------------------------------------
# script to SHOW variables
my @show;
for (1..5) {
	diag 'Bug #38: Variables with # syntax not parsed by $Macro->define()';
	diag 'Bug #39: Undefined #var use causes perl error message without location';
	#push @show, "\"N$_ = #N$_ = \$Var{N$_}\"";
	push @show, "\"N$_=\".(defined(\$Var{N$_}) ? \"\$Var{N$_}=\$Var{N$_}\" : '')";
}
my $show = join(".', '.", @show).".'.'";

#------------------------------------------------------------------------------
# define
$ms = new_ok('Text::MacroScript' => [ 
				-variable => [ 
					[ N1 => 1 ],
					[ N2 => 2 ],
				],
				-script => [
					[ SHOW => $show ],
				],
			]);
$ms->define( -variable => N3 => 3 );
$ms->define_variable( N4 => 4 );
is $ms->expand('%DEFINE_VARIABLE N5[5]'), "";

is $ms->expand($show),	
			   $show;
is $ms->expand("SHOW"), 
			   "N1=1=1, N2=2=2, N3=3=3, N4=4=4, N5=5=5.";

#------------------------------------------------------------------------------
# undefine
$ms->undefine(-variable => "N3");
$ms->undefine_variable("N4");
is $ms->expand('%UNDEFINE_VARIABLE N5'), "";

is $ms->expand("SHOW"), 
			   "N1=1=1, N2=2=2, N3=, N4=, N5=.";

#------------------------------------------------------------------------------
# list
# Use YEAR, MONTH to make sure Fix #18: output order of list() not predictable
# is fixed
for (1..5) {
	$ms->undefine_variable("N$_");
}
$ms->define_variable(YEAR => 2015);
$ms->define_variable(MONTH => 'April');

my @output;

@output = $ms->list(-variable, -namesonly);
is_deeply \@output, ["%DEFINE_VARIABLE MONTH", 
					 "%DEFINE_VARIABLE YEAR"];

@output = $ms->list(-variable);
is_deeply \@output, ["%DEFINE_VARIABLE MONTH [April]\n", 
					 "%DEFINE_VARIABLE YEAR [2015]\n"];

($out,$err,@res) = capture { void { $ms->list(-variable, -namesonly); } };
eq_or_diff $out, "%DEFINE_VARIABLE MONTH\n".
				 "%DEFINE_VARIABLE YEAR\n";
is $err, "";
is_deeply \@res, [];

($out,$err,@res) = capture { void { $ms->list(-variable); } };
eq_or_diff $out, "%DEFINE_VARIABLE MONTH [April]\n\n".
				 "%DEFINE_VARIABLE YEAR [2015]\n\n";
is $err, "";
is_deeply \@res, [];

@output = $ms->list_variable(-namesonly);
is_deeply \@output, ["%DEFINE_VARIABLE MONTH", 
					 "%DEFINE_VARIABLE YEAR"];

@output = $ms->list_variable();
is_deeply \@output, ["%DEFINE_VARIABLE MONTH [April]\n", 
					 "%DEFINE_VARIABLE YEAR [2015]\n"];

($out,$err,@res) = capture { void { $ms->list_variable(-namesonly); } };
eq_or_diff $out, "%DEFINE_VARIABLE MONTH\n".
				 "%DEFINE_VARIABLE YEAR\n";
is $err, "";
is_deeply \@res, [];

($out,$err,@res) = capture { void { $ms->list_variable(); } };
eq_or_diff $out, "%DEFINE_VARIABLE MONTH [April]\n\n".
				 "%DEFINE_VARIABLE YEAR [2015]\n\n";
is $err, "";
is_deeply \@res, [];

#------------------------------------------------------------------------------
# undefine_all
for (1..5) {
	$ms->define_variable("N$_", $_);
}
is $ms->expand("SHOW"), 
			   "N1=1=1, N2=2=2, N3=3=3, N4=4=4, N5=5=5.";

$ms->undefine_all(-variable);
is $ms->expand("SHOW"), 
			   "N1=, N2=, N3=, N4=, N5=.";

for (1..5) {
	$ms->define_variable("N$_", $_);
}
is $ms->expand("SHOW"), 
			   "N1=1=1, N2=2=2, N3=3=3, N4=4=4, N5=5=5.";

$ms->undefine_all_variable;
is $ms->expand("SHOW"), 
			   "N1=, N2=, N3=, N4=, N5=.";

for (1..5) {
	$ms->define_variable("N$_", $_);
}
is $ms->expand("SHOW"), 
			   "N1=1=1, N2=2=2, N3=3=3, N4=4=4, N5=5=5.";
diag 'Bug #6: %UNDEFINE_ALL_VARIABLE does not work';
#is $ms->expand("%UNDEFINE_ALL_VARIABLE"), "";
#is $ms->expand("SHOW"), 
#			   "N1=, N2=, N3=, N4=, N5=.";

#------------------------------------------------------------------------------
# compute
# Enhancement #40: Variables should accept expressions and compute them
#for (1..5) {
#	$ms->define_variable("N$_", ($_*2)."/2");
#}
#is $ms->expand("SHOW"), 
#			   "N1=1=1, N2=2=2, N3=3=3, N4=4=4, N5=5=5.";
#
#for (1..5) {
#	is $ms->expand("%DEFINE_VARIABLE N$_ [".($_*2)."/2]"), "";
#}
#is $ms->expand("SHOW"), 
#			   "N1=1=1, N2=2=2, N3=3=3, N4=4=4, N5=5=5.";
#
#$ms->define_variable("N1", "#N1+1");
#is $ms->expand("SHOW"), 
#			   "N1=2=2, N2=2=2, N3=3=3, N4=4=4, N5=5=5.";
#
#is $ms->expand("%DEFINE_VARIABLE N1 [#N1+1]"), "";
#is $ms->expand("SHOW"), 
#			   "N1=3=3, N2=2=2, N3=3=3, N4=4=4, N5=5=5.";
			   
done_testing;
