#!/usr/bin/perl

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Test::More;

my $ms;

use_ok 'Text::MacroScript';

$ms = new_ok('Text::MacroScript');
$ms->define( -variable, YEAR => 2015 );
$ms->define( -variable, MONTH => 'April' );
is $ms->expand("%CASE[0]\n"), "";
is $ms->expand("xxx\n"), "";
is $ms->expand("yyy\n"), "";
is $ms->expand("zzz\n"), "";
is $ms->expand("%END_CASE\n"), "";

is $ms->expand("%CASE[1]\n"), "";
is $ms->expand("xxx\n"), "xxx\n";
is $ms->expand("yyy\n"), "yyy\n";
is $ms->expand("zzz\n"), "zzz\n";
is $ms->expand("%END_CASE\n"), "";

is $ms->expand("%CASE[#YEAR == 2015]\n"), "";
is $ms->expand("xxx\n"), "xxx\n";
is $ms->expand("%END_CASE\n"), "";

is $ms->expand("%CASE[#YEAR != 2015]\n"), "";
is $ms->expand("xxx\n"), "";
is $ms->expand("%END_CASE\n"), "";

is $ms->expand("%CASE[\$Var{MONTH} eq 'April']\n"), "";
is $ms->expand("xxx\n"), "xxx\n";
is $ms->expand("%END_CASE\n"), "";

is $ms->expand("%CASE[\$Var{MONTH} ne 'April']\n"), "";
is $ms->expand("xxx\n"), "";
is $ms->expand("%END_CASE\n"), "";

done_testing;