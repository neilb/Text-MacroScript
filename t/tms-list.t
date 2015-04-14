#!/usr/bin/perl -w

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Test::More;
use Test::Differences;
use Capture::Tiny 'capture';

my $ms;
my($out,$err,@res);

sub void(&) { $_[0]->(); () }

use_ok 'Text::MacroScript';

$ms = new_ok('Text::MacroScript');
$ms->define( -macro, N1 => 1 );
$ms->define( -macro, N2 => 2 );
$ms->define( -script, ADD => '#0+#1' );
$ms->define( -script, SUB => '#0-#1' );
$ms->define( -variable, YEAR => 2015 );
$ms->define( -variable, MONTH => 'April' );

#------------------------------------------------------------------------------
# list macros
($out,$err,@res) = capture { void { $ms->list( -macro ); } };
eq_or_diff $out, norm_nl(<<'END');
%DEFINE N1 [1]

%DEFINE N2 [2]

END
is $err, "";
is_deeply \@res, [];

($out,$err,@res) = capture { $ms->list( -macro ); };
is $out, "";
is $err, "";
is_deeply \@res, ["%DEFINE N1 [1]\n", 
				  "%DEFINE N2 [2]\n"];

#------------------------------------------------------------------------------
# list macros -namesonly
($out,$err,@res) = capture { void { $ms->list( -macro, -namesonly ); } };
eq_or_diff $out, norm_nl(<<'END');
%DEFINE N1
%DEFINE N2
END
is $err, "";
is_deeply \@res, [];

($out,$err,@res) = capture { $ms->list( -macro, -namesonly ); };
is $out, "";
is $err, "";
is_deeply \@res, ["%DEFINE N1", 
				  "%DEFINE N2"];

#------------------------------------------------------------------------------
# list scripts
($out,$err,@res) = capture { void { $ms->list( -script ); } };
eq_or_diff $out, norm_nl(<<'END');
%DEFINE_SCRIPT ADD [#0+#1]

%DEFINE_SCRIPT SUB [#0-#1]

END
is $err, "";
is_deeply \@res, [];

($out,$err,@res) = capture { $ms->list( -script ); };
is $out, "";
is $err, "";
is_deeply \@res, ["%DEFINE_SCRIPT ADD [#0+#1]\n", 
				  "%DEFINE_SCRIPT SUB [#0-#1]\n"];

#------------------------------------------------------------------------------
# list scripts -namesonly
($out,$err,@res) = capture { void { $ms->list( -script, -namesonly ); } };
eq_or_diff $out, norm_nl(<<'END');
%DEFINE_SCRIPT ADD
%DEFINE_SCRIPT SUB
END
is $err, "";
is_deeply \@res, [];

($out,$err,@res) = capture { $ms->list( -script, -namesonly ); };
is $out, "";
is $err, "";
is_deeply \@res, ["%DEFINE_SCRIPT ADD", 
				  "%DEFINE_SCRIPT SUB"];

#------------------------------------------------------------------------------
# list variables
($out,$err,@res) = capture { void { $ms->list( -variable ); } };
eq_or_diff $out, norm_nl(<<'END');
%DEFINE_VARIABLE YEAR [2015]

%DEFINE_VARIABLE MONTH [April]

END
is $err, "";
is_deeply \@res, [];

($out,$err,@res) = capture { $ms->list( -variable ); };
is $out, "";
is $err, "";
is_deeply \@res, ["%DEFINE_VARIABLE YEAR [2015]\n", 
				  "%DEFINE_VARIABLE MONTH [April]\n"];

#------------------------------------------------------------------------------
# list variables -namesonly
($out,$err,@res) = capture { void { $ms->list( -variable, -namesonly ); } };
eq_or_diff $out, norm_nl(<<'END');
%DEFINE_VARIABLE YEAR
%DEFINE_VARIABLE MONTH
END
is $err, "";
is_deeply \@res, [];

($out,$err,@res) = capture { $ms->list( -variable, -namesonly ); };
is $out, "";
is $err, "";
is_deeply \@res, ["%DEFINE_VARIABLE YEAR", 
				  "%DEFINE_VARIABLE MONTH"];

done_testing;

sub norm_nl {
	local($_) = @_;
	s/\r\n/\n/g;
	return $_;
}
