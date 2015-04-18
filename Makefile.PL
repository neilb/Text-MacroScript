use strict;
use warnings;
use ExtUtils::MakeMaker ;
require 5.010;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'         => 'Text::MacroScript',
    'VERSION_FROM' => 'MacroScript.pm', # finds $VERSION
    'DISTNAME'     => 'Text-MacroScript',
    ($] >= 5.005 ?
        (
            ABSTRACT => 'A macro pre-processor with embedded perl capability', 
            AUTHOR   => 'Mark Summerfield <summer@perlpress.com>',
        ) : () ),
    'LIBS'         => [''],   # e.g., '-lm'
    'DEFINE'       => '',     # e.g., '-DHAVE_SOMETHING'
    'INC'          => '',     # e.g., '-I/usr/include/other'
	'PREREQ_PM'	   => {
		'Image::Size' => 3.3,
		'Path::Tiny' => 0.068,
		'Capture::Tiny' => 0.22,
		'Test::Differences' => 0.61,
	},
	'EXE_FILES'	   => [
		'macropp',
		'macrodir',
	],
    'dist'         => { COMPRESS => "gzip -9", SUFFIX => "gz" }
) ;
