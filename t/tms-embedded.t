#!/usr/bin/perl

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Test::More;

my $ms;

use_ok 'Text::MacroScript';

#------------------------------------------------------------------------------
# -embedded
$ms = new_ok('Text::MacroScript' => [ -embedded => 1 ]);
diag 'Issue #2: expand() does not accept a multi-line text';
#is $ms->expand_embedded("hello<:%DEFINE *\nHallo\nWelt\n%END_DEFINE:>world<:*:>\n"),
#	"helloworldHallo\nWelt\n";

for ([ [ -embedded => 1 ], 							"<:", ":>" ],
     [ [ -opendelim => "<<", -closedelim => ">>" ], "<<", ">>" ],
     [ [ -opendelim => "!!" ], 						"!!", "!!" ],
	) {
	my($args, $OPEN, $CLOSE) = @$_;
	my @args = @$args;
	note "@args $OPEN $CLOSE";
	
	$ms = new_ok('Text::MacroScript' => [ @args ]);
	is $ms->expand_embedded("hello${OPEN}%DEFINE *\n"),	"hello";
	is $ms->expand_embedded("Hallo\nWelt\n"),		"";
	is $ms->expand_embedded("%END_DEFINE${CLOSE}world${OPEN}"),"world";
	is $ms->expand_embedded("*${CLOSE}\n"),				"Hallo\nWelt\n\n";
	
}

done_testing;
