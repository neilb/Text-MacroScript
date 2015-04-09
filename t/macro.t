#!/usr/bin/perl -w

# Copyright (c) 2015 Paulo Custodio. All Rights Reserved.
# May be used/distributed under the GPL.

use strict;
use warnings;
use Test::More;
use Capture::Tiny 'capture';
use File::Slurp::Tiny 'write_file';

my $macro = "perl macro";

my $macros = "test_macros~";
write_file($macros, <<END);
%%[Silly scripts]
%DEFINE Hello [Hallo]
%DEFINE_VARIABLE name [Welt]
%DEFINE_SCRIPT World[#name]
END

my $test1 = "test1~";
write_file($test1, <<END);
Hello World
END

my $test2 = "test2~";
write_file($test2, <<END);
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

is unlink($macros, $test1, $test2), 3;
done_testing;

#------------------------------------------------------------------------------
sub t_macro {
	my($args, $output) = @_;
	my $cmd = "$macro $args";
	ok 1, "line ".(caller)[2]." - $cmd";
	my($out,$err,$res) = capture { system $cmd; };
	is $out, $output;
	is $err, "";
	is $res, 0;
}
