#!/usr/bin/perl

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

done_testing;

sub norm_nl {
	local($_) = @_;
	s/\r\n/\n/g;
	return $_;
}
