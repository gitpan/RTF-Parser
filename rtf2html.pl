#!/usr/local/bin/perl
# Sonovision-Itep, Verdret 1995-1998

# You can try this converter on replicas.rtf
# from <http://www.research.microsoft.com/~gray/replicas.rtf>

require 5.000;
use strict;

my $VERSION = "0.9";

use Getopt::Long;
use File::Basename;

use vars qw/$BASENAME $DIRNAME/;
($BASENAME, $DIRNAME) = fileparse($0); 
my $usage = "usage: $BASENAME [-h] [-l log file] RTF file(s)";
my $help = "";

use vars qw($EOM $trace);
$EOM = "\n";			# end of message
$trace = 0;
use RTF::Config;

die "$usage$EOM" unless @ARGV;
use vars qw($EOM $trace $opt_d $opt_h $opt_t $opt_v);
{ local $SIG{__WARN__} = sub {};
  GetOptions('h',			# Help
	     't=s',		# name of the target document
	     'r=s',		# name of the report file
	     'd',		# debugging mode
	     'v',		# verbose
	     'l=s' => \$LOG_FILE, # -l logfile
	    ) or die "$usage";
}

if ($opt_h) {
  print STDOUT "$help\n";
  exit 0;
}
if ($opt_d) {
  $| = 1;
  $EOM = "";
}

select(STDOUT);

require RTF::HTML::Output;
my $self = new RTF::HTML::Output;	

foreach my $filename (@ARGV) {
  $self->parseFile($filename);
}

1;
