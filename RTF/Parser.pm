# Sonovision-Itep, Philippe Verdret 1998-1999
# An event-driven RTF parser

require 5.004;
use strict;
package RTF::Parser;

$RTF::Parser::VERSION = "1.04";
use RTF::Config;
use File::Basename;

use constant PARSER_TRACE => 0;
sub backtrace { 
  require Carp;
  Carp::confess;			
}
$SIG{'INT'} = \&backtrace if PARSER_TRACE;
$SIG{__DIE__} = \&backtrace if PARSER_TRACE;
 
# Parser::Generic
sub parseStream {
  my $self = shift;
  my $stream = shift;
  unless (defined $stream) {
    die "file not defined";
  }
  $self->{filename} = '';
  local(*F) = $stream;
  unless (fileno F) {
    $self->{filename} = $stream;     # Assume $stream is a filename
    open(F, $stream) or die "Can't open '$stream' ($!)";
  }
  binmode(F); # or something like this
  $self->{filehandle} = \*F;
  $self->{'eof'} = 0;
  local *if_data_needed = \&read;
  my $buffer = '';
  $self->{'buffer'} = \$buffer;
				# accept empty file???
  $self->if_data_needed() or die "unexpected end of data";
  $self->parse();
  close(F) if $self->{filename} ne '';
  $self;
}
sub parseString {
  my $self = shift;
  $self->{filehandle} = $self->{filename} = '';
  $self->{'eof'} = 0;
  local *if_data_needed = sub { 0 };
  my $buffer = $_[0];
  $self->{'buffer'} = \$buffer;
  $self->parse();
  $self;
}
sub new {
  my $receiver = shift;
  my $class = (ref $receiver or $receiver);
  my $self = bless {
		    'buffer' => '', # internal buffer
		    'eof' => 0,	# 1 if EOF, not used
		    'filename' => '', # filename
		    'filehandle' => '',	# filehandle to read
		    'line' => 0, # not used
		   }, $class;
  $self;
}

sub line { $_[1] ? $_[0]->{line} = $_[1] : $_[0]->{line} } 
sub filename { $_[1] ? $_[0]->{filename} = $_[1] : $_[0]->{filename} } 
sub buffer { $_[1] ? $_[0]->{buffer} = $_[1] : $_[0]->{buffer} } 
sub eof { $_[1] ? $_[0]->{eof} = $_[1] : $_[0]->{eof} } 

sub error {			# not used
  my($self, $message) = @_;
  my $atline = $.;
  my $infile = $self->{filename};
}
#################################################################################
my $EOR = "\n";
if ($OS eq 'UNIX') {
  $EOR = q!\r?\n!;		# todo: autodetermination
} else {
  $EOR = q!\n!;	
}
			
# interface must change if you want to write: $self->$1($1, $2);
# $self->$control($control, $arg, 'start');
my $DO_ON_CONTROL = \%RTF::Control::do_on_control; # default
sub controlDefinition {
  my $self = shift;
  if (@_) {
    if (ref $_[0]) {
      $DO_ON_CONTROL = shift;
    } else {
      die "argument of controlDefinition method must be an HASHREF";
    }
  } else {
    $DO_ON_CONTROL;
  }
}
{ package RTF::Action;		
  use RTF::Config;

  use vars qw($AUTOLOAD);
  my $default = $LOG_FILE ? 
    sub { $RTF::Control::not_processed{$_[1]}++ } : 
      sub {};
  sub AUTOLOAD {
    my $self = $_[0];
    $AUTOLOAD =~ s/^.*:://;	
    no strict 'refs';
    if (defined (my $sub = ${$DO_ON_CONTROL}{"$AUTOLOAD"})) {
      # Generate on the fly a new method and call it
      #*{"$AUTOLOAD"} = $sub; &{"$AUTOLOAD"}(@_); 
      # in the OOP style: *{"$AUTOLOAD"} = $sub; $self->$AUTOLOAD(@_);
      goto &{*{"$AUTOLOAD"} = $sub}; 
    } else {
      goto &{*{"$AUTOLOAD"} = $default};	
    }
  }
}
sub DESTROY {}
			# API
sub parseStart {}
sub parseEnd {}
sub groupStart {}
sub groupEnd {}
sub text {}
sub char {}
sub symbol {}
sub destination {}
sub bitmap {}
sub binary {}			

# RTF Specification
# The delimiter marks the end of the RTF control word, and can
# be one of the following:
# 1. a space. In this case, the space is part of the control word
# 2. a digit or an hyphen, ...
# 3. any character other than a letter or a digit
# 
my $CONTROL_WORD = '[a-z]{1,32}'; # '[a-z]+';
my $CONTROL_ARG = '-?\d+';	# argument of control words, or: (?:-\d+|\d+)
my $END_OF_CONTROL = '(?:[ ]|(?=[^a-z0-9]))'; 
my $CONTROL_SYMBOLS = q![-_~:|{}*\'\\\\]!; # Symbols (Special characters)
my $DESTINATION = '[*]';	# 
my $DESTINATION_CONTENT = '(?:[^\\\\{}]+|\\\\.)+'; 
my $HEXA = q![0-9abcdef][0-9abcdef]!;
my $PLAINTEXT = '[^{}\\\\]+'; 
my $BITMAP_START = '\\\\{bm(?:[clr]|cwd) '; # Ex.: \{bmcwd 
my $BITMAP_END = q!\\\\}!;
my $BITMAP_FILE = '(?:[^\\\\{}]+|\\\\[^{}])+'; 

sub parse {
  my $self = shift;
  my $buffer = ${$self->{'buffer'}};
  $self->{'buffer'} = \$buffer;
  my $guard = 0;
  $self->parseStart();		# Action before parsing
  while (1) {
    $buffer =~ s/^\\($CONTROL_WORD)($CONTROL_ARG)?$END_OF_CONTROL//o and do {
      my ($control, $arg) = ($1, $2);
      no strict 'refs';		
      &{"RTF::Action::$control"}($self, $control, $arg, 'start');
      next;
    };
    $buffer =~ s/^\{\\$DESTINATION\\($CONTROL_WORD)($CONTROL_ARG)?$END_OF_CONTROL//o and do { 
      # RTF Specification: "discard all text up to and including the closing brace"
      # Example:  {\*\controlWord ... }
      # '*' is an escaping mechanism

      if (defined ${$DO_ON_CONTROL}{$1}) { # if it's a registered control then don't skip
	$buffer = "\{\\$1$2" . $buffer;
      } else {			# skip!
	my $level = 1;
	my $content = "\{\\*\\$1$2";
	$self->{'start'} = $.;		# could be used by the error() method
	while (1) {
	  $buffer =~ s/^($DESTINATION_CONTENT)//o and do {
	    $content .= $1;
	    next
	  };
	  $buffer =~ s/^\{// and do {
	    $content .= "\{";
	    $level++;
	    next;
	  };
	  $buffer =~ s/^\}// and do { # 
	    $content .= "\}";
	    --$level == 0 and last;
	    next;
	  };
	  if ($buffer eq '') {
	    $self->if_data_needed() 
	      or 
		die "unexpected end of data: unable to find end of destination"; 
	    next;
	  } else {
	    die "unable to analyze '$buffer' in destination"; 
	  }
	}
	$self->destination($content);
      }
      next;
    };
    $buffer =~ s/^\{(?!\\[*])// and do { # can't be a destination
      $self->groupStart();
      next;
    };

    $buffer =~ s/^\}// and do {		# 
      $self->groupEnd();
      next;
    };
    $buffer =~ s/^($PLAINTEXT)//o and do {
      $self->text($1);
      next;
    };
    $buffer =~ s/^\\\'($HEXA)//o and do {
      $self->char($1);	
      next;
    };
    $buffer =~ s/^$BITMAP_START//o and do { # bitmap filename
      my $filename;
      do {
	$buffer =~ s/^($BITMAP_FILE)//o;
	$filename .= $1;
	
	if ($buffer eq '') {
	  $self->if_data_needed() 
	    or 
	      die "unexpected end of data"; 
	}

      } until ($buffer =~ s/^$BITMAP_END//o);
      $self->bitmap($filename);
      next;
    };
    $buffer =~ s/^\\($CONTROL_SYMBOLS)//o and do {
      $self->symbol($1);
      next;
    };
    $self->if_data_needed() and next;
    # can't goes there if everything is alright, except one time on eof
    last if $guard++ > 0;	
  }
				# could be in parseEnd()
  if ($buffer ne '') {  
    my $data = substr($buffer, 0, 100);
    die "unanalized data: '$data ...' at line $. file $self->{filename}\n";  
  }
  $self->parseEnd();		# Action after
  $self;
}
# what is the most efficient reader? I don't know
sub read {			# by line
  my $self = $_[0];
  my $FH = $self->{'filehandle'};
  if (${$self->{'buffer'}} .= <$FH>) {
    ${$self->{'buffer'}} =~ s!($EOR)$!!o;
    $self->{strimmed} = $1;
    1;
  } else {
    $self->{eof} = 1;
    0;
  }
}
use constant READ_BIN => 0;
sub read_bin {
  my $self = shift;
  my $length = shift;
  print STDERR "need to read $length chars\n" if READ_BIN;
  my $bufref = $self->{'buffer'};
  my $fh = $self->{'filehandle'};
  my $binary = $$bufref . $self->{strimmed};
  my $toread = $length - length($binary);
  print STDERR "data to read: $toread\n" if READ_BIN;
  if ($toread > 0) {
    my $n = read($fh, $binary, $toread, length($binary));
    print STDERR "binary data: $n chars\n" if READ_BIN;
    unless ($toread == $n) {
      die "unable to read binary data\n";
    }
  } else {
    $binary = substr($$bufref, 0, $length);
    substr($$bufref, 0, $length) = '';
    print STDERR "data to analyze: $$bufref\n" if READ_BIN;
  }
  $self->binary($binary);	# and call the binary() method
}
1;
__END__


