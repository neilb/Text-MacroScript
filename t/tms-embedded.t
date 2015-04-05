#!/usr/bin/perl -w

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
# Enhancement #2: expand() does not accept a multi-line text
#is $ms->expand_embedded("hello<:%DEFINE *\nHallo\nWelt\n%END_DEFINE:>world<:*:>\n"),
#	"helloworldHallo\nWelt\n";

$ms = new_ok('Text::MacroScript' => [ -embedded => 1 ]);
is $ms->expand_embedded("hello<:%DEFINE *\n"),	"hello";
is $ms->expand_embedded("Hallo\nWelt\n"),		"";
is $ms->expand_embedded("%END_DEFINE:>world<:"),"world";
is $ms->expand_embedded("*:>\n"),				"Hallo\nWelt\n\n";

done_testing;
