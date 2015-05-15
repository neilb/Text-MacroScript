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

use_ok 'Text::MacroScript';
require_ok 't/mytests.pl';

sub void(&) { $_[0]->(); () }

my $ms;
my $fh;
my($out,$err,@res);

#------------------------------------------------------------------------------
# capture $! for file not found and permission denied
ok ! open($fh, "NOFILE");
my $file_not_found = $!;

ok ! open($fh, ".");
my $permission_denied = $!;

#------------------------------------------------------------------------------
# create object
$ms = new_ok('Text::MacroScript');

#------------------------------------------------------------------------------
# open file failed
eval { $ms->expand_file; };
check_error(__LINE__-1, $@, "Missing filename __LOC__.\n");

eval { $ms->expand_file("NOFILE"); };
check_error(__LINE__-1, $@, "File 'NOFILE' does not exist __LOC__.\n");

path("testdir~")->mkpath;
eval { $ms->expand_file("testdir~"); };
check_error(__LINE__-1, $@, "Open 'testdir~' failed: $permission_denied __LOC__.\n");
path("testdir~")->remove_tree;

#------------------------------------------------------------------------------
# open file in ~
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

#------------------------------------------------------------------------------
# error messages: unclosed %DEFINE
my $file = "testmacroscript.tmp~";

path($file)->spew("\n\n%DEFINE xx\nyy\nzz\n");
$ms = new_ok('Text::MacroScript');
eval { @res = $ms->expand_file($file); };
check_error(__LINE__-1, $@, "Runaway %DEFINE from $file line 3 to end of file __LOC__.\n");
path($file)->remove;

#------------------------------------------------------------------------------
# error messages: unclosed %DEFINE_SCRIPT
path($file)->spew("\n\n%DEFINE_SCRIPT xx\nyy\nzz\n");
$ms = new_ok('Text::MacroScript');
eval { @res = $ms->expand_file($file); };
check_error(__LINE__-1, $@, "Runaway %DEFINE_SCRIPT from $file line 3 to end of file __LOC__.\n");
path($file)->remove;

#------------------------------------------------------------------------------
# error messages: %CASE inside %DEFINE...
for my $define (qw( DEFINE DEFINE_SCRIPT )) {
	for my $case ('CASE[0]', 'CASE[1]', 'END_CASE') {
		path($file)->spew("\n\n%$define xx\nyy\nzz\n%$case");
		diag path($file)->lines;
		$ms = new_ok('Text::MacroScript');
		eval { @res = $ms->expand_file($file); };
		check_error(__LINE__-1, $@, "Runaway %$define from $file line 3 to line 6 __LOC__.\n");
		path($file)->remove;
	}
}

#------------------------------------------------------------------------------
# error messages: no %CASE argument
path($file)->spew("\n\n%CASE 1\nyy\nzz\n");
$ms = new_ok('Text::MacroScript');
eval { @res = $ms->expand_file($file); };
check_error(__LINE__-1, $@, "Missing \%CASE condition at $file line 3 __LOC__.\n");
path($file)->remove;

#------------------------------------------------------------------------------
# error messages: %CASE eval failed
diag 'Issue #46: Syntax error in %CASE expression is not caught'; 
#path($file)->spew("\n\n%CASE[1+]\nyy\nzz\n");
#$ms = new_ok('Text::MacroScript');
#eval { @res = $ms->expand_file($file); };
#check_error(__LINE__-1, $@, "Evaluation of %CASE [1+] failed at $file line 3 __LOC__.\n");
#path($file)->remove;

#------------------------------------------------------------------------------
# error messages: %??? inside %DEFINE
for my $define (qw( DEFINE DEFINE_SCRIPT )) {
	for my $stmt (qw( UNDEFINE UNDEFINE_ALL
					  UNDEFINE_SCRIPT UNDEFINE_ALL_SCRIPT 
					  UNDEFINE_VARIABLE UNDEFINE_ALL_VARIABLE
					  DEFINE DEFINE_SCRIPT DEFINE_VARIABLE
					  LOAD INCLUDE 
					  CASE END_CASE )) {
		path($file)->spew("\n\n%$define xx\nyy\nzz\n%$stmt");
		diag path($file)->lines;
		$ms = new_ok('Text::MacroScript');
		eval { @res = $ms->expand_file($file); };
		check_error(__LINE__-1, $@, "Runaway %$define from $file line 3 to line 6 __LOC__.\n");
		path($file)->remove;
	}
}

#------------------------------------------------------------------------------
# error messages: evaluation error within script
diag "Issue #47 eval error when evaluating a SCRIPT is not caught and Perl error message is output";
#path($file)->spew(<<'END');
#%DEFINE_SCRIPT xx ["]
#xx
#END
#$ms = new_ok('Text::MacroScript');
#eval { @res = $ms->expand_file($file); };
#check_error(__LINE__-1, $@, "Evaluation of SCRIPT xx failed at $file line 2 __LOC__.\n");
#path($file)->remove;

done_testing;
