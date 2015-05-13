#!/usr/bin/perl

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Capture::Tiny 'capture';
use Path::Tiny;
use POSIX 'strftime';
use Test::Differences;
use Test::More;

use_ok 'Text::MacroScript';
require_ok 't/mytests.pl';

my $ms;
my $test1 = "test~";
my($out,$err,@res);

path($test1)->spew(norm_nl(<<'END'));
Test text with hello
%DEFINE hello [world]
Test text with hello
END

#------------------------------------------------------------------------------
# new()
eval { Text::MacroScript->new(-no=>0,-such=>0,-option=>0); }; 
check_error(__LINE__-1, $@, "Invalid options -such,-no,-option __LOC__.\n");

#------------------------------------------------------------------------------
# -file
$ms = new_ok('Text::MacroScript' => [ -file => [ $test1 ] ] );
is $ms->expand("hello"), "world";

#------------------------------------------------------------------------------
# %LOAD
$ms = new_ok('Text::MacroScript');
is $ms->expand("hello"), "hello";
is $ms->expand("%LOAD[$test1]\n"), "";
is $ms->expand("hello"), "world";

#------------------------------------------------------------------------------
# load_file
$ms = new_ok('Text::MacroScript');
is $ms->expand("hello"), "hello";
$ms->load_file($test1);
is $ms->expand("hello"), "world";

#------------------------------------------------------------------------------
# %INCLUDE
$ms = new_ok('Text::MacroScript');
is $ms->expand("%INCLUDE[$test1]\n"), 
	"Test text with hello\n".
	"Test text with world\n";

#------------------------------------------------------------------------------
# %REQUIRE
$ms = new_ok('Text::MacroScript');
is $ms->expand("%REQUIRE[examples/macroutil.pl]\n"), "";
is $ms->expand("%DEFINE_SCRIPT copyright [copyright(#0,#1)]"), "";
is $ms->expand("copyright['Paulo Custodio'|2015]"), 
	"<hr />\n".
	"Copyright &copy; 2015 Paulo Custodio. All&nbsp;Rights&nbsp;Reserved. ".
	"Updated&nbsp;".strftime("%Y/%m/%d", localtime).".\n".
	"<!-- Generated by Text::MacroScript -->\n";

ok unlink($test1);

done_testing;