#!/usr/bin/perl -w

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Test::More;
use File::Slurp::Tiny qw( write_file );

my $ms;
my $test_file = "test~";

use_ok 'Text::MacroScript';

write_file($test_file, <<'END');
%DEFINE hello [world]
This is not output
END

#------------------------------------------------------------------------------
# -file
$ms = new_ok('Text::MacroScript' => [ -file => [ $test_file ] ] );
is $ms->expand("hello"), "world";

#------------------------------------------------------------------------------
# %LOAD
$ms = new_ok('Text::MacroScript');
is $ms->expand("hello"), "hello";
is $ms->expand("%LOAD[$test_file]\n"), "";
is $ms->expand("hello"), "world";

ok unlink($test_file);

done_testing;