#!/usr/bin/perl

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Capture::Tiny 'capture';
use Path::Tiny;
use Test::Differences;
use Test::More;

use_ok 'Text::MacroScript';
require_ok 't/mytests.pl';

my $ms;
my $fh;
my($out,$err,@res);

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
