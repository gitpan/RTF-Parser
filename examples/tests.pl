#!/usr/local/bin/perl
require 5.000;
use strict;

my $VERSION = "1.03";

use Getopt::Long;
use File::Basename;

use vars qw/$BASENAME $DIRNAME/;
BEGIN {
  ($BASENAME, $DIRNAME) = fileparse($0); 
#  unshift @INC, "/users/phv/RTF/rtfparser/rtfparser-1.03";
}
use lib $DIRNAME;

select(STDOUT);

require RTF::HTML::Output;
my $self = new RTF::HTML::Output;	

if (@ARGV)  {
  foreach my $filename (@ARGV) {
    $self->parse_stream($filename);
  }
} else {
  while (<DATA>) {
    s/\#.*//;
    next unless /\S/;
    print STDERR "-" x 30, "\n";
    print STDERR "RTF string: $_";
    print STDERR "-" x 30, "\n";
    $self->parse_string($_);
  }
}
__END__
#{} # Ok!
#{\par} # Ok!
#{string\par} # Ok!
#{\b bold {\i italic} bold \par} # Ok!
#{\b introduction \par } # Ok!
#{\b first B{\b0 mm{\b b}m}b} #!Ok
#{\b first B{\b0 mm{\b b}m}b\par} # !Ok
#{\i {\b first B{\b0 mm{\b b}m}b\par second B}}!Ok
#{{\par }\b {Introduction\par }}
#{\pard\plain \b{Introduction\par }}
#{\b bold \i Bold Italic \i0 Bold again} # Ok!
#{\b bold {\i Bold Italic }Bold again} # Ok!
{\b bold \i Bold Italic \plain\b Bold again} # Ok!
