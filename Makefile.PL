#
# Makefile.PL for RTF::Parser distribution
#
# Filename:     Makefile.PL
# Created:      21 October 1998
#

use ExtUtils::MakeMaker;

&WriteMakefile(
               NAME          => 'RTF::Parser',
               EXE_FILES     => [ 'rtf2html', 'rtf2text' ],
               DISTNAME      => 'RTF-Parser',
               VERSION_FROM  => 'lib/RTF/Parser.pm', 
               dist          => {COMPRESS => 'gzip', SUFFIX => 'gz', },
              );

