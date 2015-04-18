#!/usr/bin/perl

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Test::More;
use Test::Differences;
use Capture::Tiny 'capture';
use Path::Tiny;

use_ok 'Text::MacroScript';

my $macropp = "$^X macropp";

my $macros = "test_macros~";
path($macros)->spew(norm_nl(<<END));
%%[Silly scripts]
%DEFINE Hello [Hallo]
%DEFINE_VARIABLE name [Welt]
%DEFINE_SCRIPT World[#name]
END

my $test1 = "test1~";
path($test1)->spew(norm_nl(<<END));
Hello World
END

my $test2 = "test2~";
path($test2)->spew(norm_nl(<<END));
xxHello Worldxx
xyHello Worldyx
<:Hello World:>
END

#------------------------------------------------------------------------------
# no options, no macros - copy verbatim
t_macro("< $test1", "Hello World\n");
t_macro("  $test1", "Hello World\n");
t_macro("$test1 $test1", "Hello World\nHello World\n");

#------------------------------------------------------------------------------
# -C --comment
t_macro("          $macros", "%%[Silly scripts]\n");
t_macro("       -C $macros", "\n");
t_macro("--comment $macros", "\n");

#------------------------------------------------------------------------------
# -f, --file
t_macro("-f     $macros $test1", "Hallo Welt\n");
t_macro("--file $macros $test1", "Hallo Welt\n");

#------------------------------------------------------------------------------
# -m, --macro
t_macro("-f $macros -m     ", "%DEFINE Hello [Hallo]\n\n");
t_macro("-f $macros --macro", "%DEFINE Hello [Hallo]\n\n");

#------------------------------------------------------------------------------
# -s, --script
t_macro("-f $macros -s      ", "%DEFINE_SCRIPT World [\$Var{\"name\"}]\n\n");
t_macro("-f $macros --script", "%DEFINE_SCRIPT World [\$Var{\"name\"}]\n\n");

#------------------------------------------------------------------------------
# -v, --variable
t_macro("-f $macros -v        ", "%DEFINE_VARIABLE name [Welt]\n\n");
t_macro("-f $macros --variable", "%DEFINE_VARIABLE name [Welt]\n\n");

#------------------------------------------------------------------------------
# -n, --name
t_macro("-f $macros -n       ", 
		"%DEFINE Hello\n%DEFINE_SCRIPT World\n%DEFINE_VARIABLE name\n");
t_macro("-f $macros --name   ", 
		"%DEFINE Hello\n%DEFINE_SCRIPT World\n%DEFINE_VARIABLE name\n");
t_macro("-f $macros --name -m", 
		"%DEFINE Hello\n");
t_macro("-f $macros --name -s", 
		"%DEFINE_SCRIPT World\n");
t_macro("-f $macros --name -v", 
		"%DEFINE_VARIABLE name\n");

#------------------------------------------------------------------------------
# -e --emacro
t_macro("-f $macros       -e $test2", 
		"xxHello Worldxx\nxyHello Worldyx\nHallo Welt\n");
t_macro("-f $macros --emacro $test2", 
		"xxHello Worldxx\nxyHello Worldyx\nHallo Welt\n");

#------------------------------------------------------------------------------
# -o --opendelim
t_macro("-f $macros -e          -o xx $test2", 
		"Hallo Welt\nxyHello Worldyx\n<:Hello World:>\n");
t_macro("-f $macros -e --opendelim xx $test2", 
		"Hallo Welt\nxyHello Worldyx\n<:Hello World:>\n");

#------------------------------------------------------------------------------
# -c --closedelim
t_macro("-f $macros -e -o xy           -c yx $test2", 
		"xxHello Worldxx\nHallo Welt\n<:Hello World:>\n");
t_macro("-f $macros -e -o xy --closedelim yx $test2", 
		"xxHello Worldxx\nHallo Welt\n<:Hello World:>\n");

#------------------------------------------------------------------------------
# -h --help
my $VERSION = $Text::MacroScript::VERSION;
for my $args ("-h", "--help") {
	my $cmd = "$macropp $args";
	ok 1, "- $cmd";
	my($out,$err,$res) = capture { system $cmd; };
	is $out, "";
	eq_or_diff $err, norm_nl(<<END);

macropp v $VERSION. Copyright (c) Mark Summerfield 1999-2000. 
All rights reserved. May be used/distributed under the GPL.

usage: macropp [options] infile(s) > outfile

options: (use the short or long name followed by the parameter where req'd) 
-C --comment      add the %%[] comment macro 
-f --file       s macro/script file to read (repeat for multiple files) 
-m --macro        just list macros [0] 
-n --name         just list the names of macros/scripts [0] 
                  (if no -m or -s or v are specified this sets them all) 
-s --script       just list scripts [0] 
-v --variable     just list variables [0]

-e --emacro       operate as embedded perl processor [0] 
-o --opendelim  s closing delimiter for embedded processor [] 
-c --closedelim s closing delimiter for embedded processor []

b = boolean 1 = true, 0 = false; i = integer; s = string e.g. filename

See macrodir for a different approach.
END
	is $res, 0;
}

is unlink($macros, $test1, $test2), 3;
done_testing;

#------------------------------------------------------------------------------
sub t_macro {
	my($args, $output) = @_;
	my $cmd = "$macropp $args";
	ok 1, "line ".(caller)[2]." - $cmd";
	my($out,$err,$res) = capture { system $cmd; };
	is $out, $output;
	is $err, "";
	is $res, 0;
}

sub norm_nl {
	local($_) = @_;
	s/\r\n/\n/g;
	return $_;
}

