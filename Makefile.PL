#
# Makefile.PL for RTF::Parser distribution
#
# Filename:     Makefile.PL
# Created:      21 October 1998
#

use ExtUtils::MakeMaker;

&WriteMakefile(
               NAME          => 'RTF::Parser',
               EXE_FILES     => [ 'rtf2html' ],
               DISTNAME      => 'RTF-Parser',
               VERSION_FROM  => 'RTF/Parser.pm',
               dist          => {COMPRESS => 'gzip', SUFFIX => 'gz'},
              );

