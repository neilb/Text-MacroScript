#!/usr/bin/perl

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.
#
# test expand_file

use strict;
use warnings;
use Capture::Tiny 'capture';
use Path::Tiny;
use Test::Differences;
use Test::More;

my $ms;
my $fh;
my($out,$err,@res);

sub void(&) { $_[0]->(); () }

use_ok 'Text::MacroScript';

# capture $! for file not found and permission denied
ok ! open($fh, "NOFILE");
my $file_not_found = $!;

ok ! open($fh, ".");
my $permission_denied = $!;

$ms = new_ok('Text::MacroScript');

eval { $ms->expand_file; };
check_error(__LINE__-1, $@, "Missing filename __LOC__.\n");

eval { $ms->expand_file("NOFILE"); };
check_error(__LINE__-1, $@, "File 'NOFILE' does not exist __LOC__.\n");

path("testdir~")->mkpath;
eval { $ms->expand_file("testdir~"); };
check_error(__LINE__-1, $@, "failed to open testdir~: $permission_denied __LOC__.\n");
path("testdir~")->remove_tree;

for my $file ("~/testmacroscript.tmp~", "testmacroscript.tmp~") {
	$ms = new_ok('Text::MacroScript');
	path($file)->spew("hello\nworld\n");
	if ($file =~ /^~/) {
		diag "Issue #44: expand_file(): tilde (~) for home directory does not work in windows";
		next;
	}
	@res = $ms->expand_file($file);
	is_deeply \@res, [
		"hello\n",
		"world\n",
	];

	($out,$err,@res) = capture { void { $ms->expand_file($file); } };
	is $out, 
		"hello\n".
		"world\n";
	is $err, "";

	path($file)->remove;
}

my $file = "testmacroscript.tmp~";

path($file)->spew("\n\n%DEFINE xx\nyy\nzz\n");
$ms = new_ok('Text::MacroScript');
eval { @res = $ms->expand_file($file); };
check_error(__LINE__-1, $@, "runaway %DEFINE from line 3 to end of file __LOC__.\n");
path($file)->remove;

path($file)->spew("\n\n%DEFINE_SCRIPT xx\nyy\nzz\n");
$ms = new_ok('Text::MacroScript');
eval { @res = $ms->expand_file($file); };
check_error(__LINE__-1, $@, "runaway %DEFINE_SCRIPT from line 3 to end of file __LOC__.\n");
path($file)->remove;

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
