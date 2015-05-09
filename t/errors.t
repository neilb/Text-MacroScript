#!/usr/bin/perl

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Capture::Tiny 'capture';
use Path::Tiny;
use Test::Differences;
use Test::More;

my $ms;
my $fh;
my($out,$err,@res);

use_ok 'Text::MacroScript';

# capture $! for file not found and permission denied
ok ! open($fh, "NOFILE");
my $file_not_found = $!;

ok ! open($fh, ".");
my $permission_denied = $!;

#------------------------------------------------------------------------------
# expand_file()
$ms = new_ok('Text::MacroScript');

eval { $ms->expand_file; };
check_error(__LINE__-1, $@, "Missing filename __LOC__.\n");

eval { $ms->expand_file("NOFILE"); };
check_error(__LINE__-1, $@, "File 'NOFILE' does not exist __LOC__.\n");

path("testdir~")->mkpath;
eval { $ms->expand_file("testdir~"); };
check_error(__LINE__-1, $@, "failed to open testdir~: $permission_denied __LOC__.\n");

done_testing;


#------------------------------------------------------------------------------
# check $@ for the given error message
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
