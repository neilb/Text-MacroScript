use ExtUtils::MakeMaker ;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'         => 'Macro',
    'VERSION_FROM' => 'Macro.pm', # finds $VERSION
    'DISTNAME'     => 'Macro',
    ($] >= 5.005 ?
        (
            ABSTRACT => 'A macro pre-processor with embedded perl capability', 
            AUTHOR   => 'Mark Summerfield <summer@chest.ac.uk>',
        ) : () ),
    'LIBS'         => [''],   # e.g., '-lm'
    'DEFINE'       => '',     # e.g., '-DHAVE_SOMETHING'
    'INC'          => '',     # e.g., '-I/usr/include/other'
    'dist'         => { COMPRESS => "gzip -9", SUFFIX => "gz" }
) ;
