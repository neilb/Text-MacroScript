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
	t_spew($file, "hello\nworld\n");
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

t_spew($file, "\n\n%DEFINE xx\nyy\nzz\n");
$ms = new_ok('Text::MacroScript');
eval { @res = $ms->expand_file($file); };
check_error(__LINE__-1, $@, "Runaway %DEFINE from $file line 3 to end of file __LOC__.\n");
path($file)->remove;

#------------------------------------------------------------------------------
# error messages: unclosed %DEFINE_SCRIPT
t_spew($file, "\n\n%DEFINE_SCRIPT xx\nyy\nzz\n");
$ms = new_ok('Text::MacroScript');
eval { @res = $ms->expand_file($file); };
check_error(__LINE__-1, $@, "Runaway %DEFINE_SCRIPT from $file line 3 to end of file __LOC__.\n");
path($file)->remove;

#------------------------------------------------------------------------------
# error messages: %CASE inside %DEFINE...
for my $define (qw( DEFINE DEFINE_SCRIPT )) {
	for my $case ('CASE[0]', 'CASE[1]', 'END_CASE') {
		t_spew($file, "\n\n%$define xx\nyy\nzz\n%$case");
		$ms = new_ok('Text::MacroScript');
		eval { @res = $ms->expand_file($file); };
		check_error(__LINE__-1, $@, "Runaway %$define from $file line 3 to line 6 __LOC__.\n");
		path($file)->remove;
	}
}

#------------------------------------------------------------------------------
# error messages: no %CASE argument
t_spew($file, "\n\n%CASE 1\nyy\nzz\n");
$ms = new_ok('Text::MacroScript');
eval { @res = $ms->expand_file($file); };
check_error(__LINE__-1, $@, "Missing \%CASE condition at $file line 3 __LOC__.\n");
path($file)->remove;

#------------------------------------------------------------------------------
# error messages: %CASE eval failed
diag 'Issue #46: Syntax error in %CASE expression is not caught'; 
#t_spew($file, "\n\n%CASE[1+]\nyy\nzz\n");
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
		t_spew($file, "\n\n%$define xx\nyy\nzz\n%$stmt");
		$ms = new_ok('Text::MacroScript');
		eval { @res = $ms->expand_file($file); };
		check_error(__LINE__-1, $@, "Runaway %$define from $file line 3 to line 6 __LOC__.\n");
		path($file)->remove;
	}
}

#------------------------------------------------------------------------------
# error messages: evaluation error within script
diag "Issue #47 eval error when evaluating a SCRIPT is not caught and Perl error message is output";
#t_spew($file, <<'END');
#%DEFINE_SCRIPT xx ["]
#xx
#END
#$ms = new_ok('Text::MacroScript');
#eval { @res = $ms->expand_file($file); };
#check_error(__LINE__-1, $@, "Evaluation of SCRIPT xx failed at $file line 2 __LOC__.\n");
#path($file)->remove;

#------------------------------------------------------------------------------
# error messages: undefine non-existent item
t_spew($file, <<'END');
%UNDEFINE          x1
%UNDEFINE_SCRIPT   x2
%UNDEFINE_VARIABLE x3
END
$ms = new_ok('Text::MacroScript');
t_capture(__LINE__, sub { void { $ms->expand_file($file) } }, "", <<ERR, 0 );
Cannot undefine non-existent MACRO x1 at $file line 1 __LOC__.
Cannot undefine non-existent SCRIPT x2 at $file line 2 __LOC__.
Cannot undefine non-existent VARIABLE x3 at $file line 3 __LOC__.
ERR
path($file)->remove;

for my $which (qw( macro script variable )) {
	t_capture(__LINE__, sub { $ms->undefine("-$which", "x1") }, "", 
			  "Cannot undefine non-existent ".uc($which)." x1 __LOC__.\n",
			  1 );
}

#------------------------------------------------------------------------------
# error messages: %REQUIRE
t_spew($file.".1", "1+;\n");
t_spew($file, "%REQUIRE[$file.1]\n");
$ms = new_ok('Text::MacroScript');
t_capture(__LINE__, sub { void { $ms->expand_file($file) } }, "", <<ERR, 0 );
Failed to require $file.1: syntax error at $file.1 line 1, near "+;"
Compilation failed in require at blib/lib/Text/MacroScript.pm line 687, <\$fh> line 1.
 __LOC__.
ERR
path($file.".1")->remove;
path($file)->remove;

#------------------------------------------------------------------------------
# error messages: missing parameter
t_spew($file, "%DEFINE_SCRIPT xx [\"#0#1\"]\nxx\nxx[a]\nxx[a|b]\n");
$ms = new_ok('Text::MacroScript');
t_capture(__LINE__, sub { void { $ms->expand_file($file) } }, <<OUT, <<ERR, 0 );
#0#1
a#1
ab
OUT
Missing parameter or unescaped # in SCRIPT xx "#0#1" at $file line 2 __LOC__.
Missing parameter or unescaped # in SCRIPT xx "a#1" at $file line 3 __LOC__.
ERR
path($file)->remove;

diag 'Issue #49: Missing parameter or unescaped # in MACRO not reported for all missing parameters';
#Missing parameter or unescaped # in MACRO xx a#1 at $file line 3 __LOC__.
t_spew($file, "%DEFINE xx [#0#1]\nxx\nxx[a]\nxx[a|b]\n");
$ms = new_ok('Text::MacroScript');
t_capture(__LINE__, sub { void { $ms->expand_file($file) } }, <<OUT, <<ERR, 0 );
#0#1
a#1
ab
OUT
Missing parameter or unescaped # in MACRO xx #0#1 at $file line 2 __LOC__.
ERR
path($file)->remove;

#------------------------------------------------------------------------------
# test embedded
for ([ [ -embedded => 1 ], 							"<:", ":>" ],
     [ [ -opendelim => "<<", -closedelim => ">>" ], "<<", ">>" ],
     [ [ -opendelim => "!!" ], 						"!!", "!!" ],
	) {
	my($args, $OPEN, $CLOSE) = @$_;
	my @args = @$args;
	note "@args $OPEN $CLOSE";
	
	$ms = new_ok('Text::MacroScript' => [ @args ]);
	t_spew($file, <<END);
hello ${OPEN}%DEFINE hello
Hallo
%END_DEFINE${CLOSE}world ${OPEN}%DEFINE world
Welt
%END_DEFINE${CLOSE}${OPEN}hello world${CLOSE}
END
	@res = $ms->expand_file($file);
	is_deeply \@res, ["hello ", "world ", "Hallo\n Welt\n\n"];
	path($file)->remove;

	$ms = new_ok('Text::MacroScript' => [ @args ]);
	t_spew($file, <<END);
hello ${OPEN}%DEFINE hello [Hallo]${CLOSE}world${OPEN}%DEFINE world [Welt]${CLOSE}
${OPEN}hello world${CLOSE}
END
	@res = $ms->expand_file($file);
	is_deeply \@res, ["hello world\n", "Hallo Welt\n"];
	path($file)->remove;
}




done_testing;
