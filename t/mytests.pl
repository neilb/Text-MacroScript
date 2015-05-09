#!/usr/bin/perl

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;

#------------------------------------------------------------------------------
# check $@ for the given error message, replace __LOC__ by the 
# standard "at 'FILE' line DDD", normalize slashes for pathnames
sub check_error {
	my($line_nr, $eval, $expected) = @_;
	my $where = "at line $line_nr";
	
	ok defined($eval), "error defined $where";
	$eval //= "";
	
	$expected =~ s/__LOC__/at $0 line $line_nr/g;
	for ($eval, $expected) {
		s/\\/\//g;
	}
	
	eq_or_diff $eval, $expected, "error ok $where";
}

#------------------------------------------------------------------------------
# Normalize newline CR-LF --> LF, to be used for HERE-documents,
# as script is read in :raw mode, Win32 HERE-documents (<<END) have CR-LF
sub norm_nl {
	local($_) = @_;
	s/\r\n/\n/g;
	return $_;
}

1;
