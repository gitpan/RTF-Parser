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

#foreach my $filename (@ARGV) {
#  $self->parseStream($filename);
#}
while (<DATA>) {
  next if /^#/;
  print STDERR "-" x 30, "\n";
  print STDERR "RTF string: $_";
  print STDERR "-" x 30, "\n";
  $self->parseString($_);
}
__END__
#{}
#{\par}
#{string\par}
#{\b bold {\i italic} \par}
#{\b introduction \par }
#{\b first B{\b0 mm{\b b}m}b}
#{\b first B{\b0 mm{\b b}m}b\par}
#{\i {\b first B{\b0 mm{\b b}m}b\par second B}}
#{{\par }\b {Introduction\par }}
#{\b before \par{\i Introduction\par }}
{\b bold \i Bold Italic \i0 Bold again}
{\b bold {\i Bold Italic }Bold again}
{\b bold \i Bold Italic \plain\b Bold again}
{\pard\plain \b{Introduction\par }}
