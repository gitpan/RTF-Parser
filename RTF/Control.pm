# Sonovision-Itep, Philippe Verdret 1998
# 
# Stack machine - must be application independant!
# 
# defined some interesting events for your application

# application could redefine its own control callbacks if %do_on_control was exported
use strict;
require 5.003;
package RTF::Control;
use RTF::Parser;
use RTF::Config;
use RTF::Charsets;

use Exporter;
@RTF::Control::ISA = qw(Exporter RTF::Parser);

				# here is what you can use in your application
use vars qw(%char %symbol %info %do_on_event 
	    %par_props
	    $style $newstyle $event $text);
				# symbols to export in the application layer
@RTF::Control::EXPORT = qw(output 
			   %char %symbol %info %do_on_event 
			   %par_props
			   $style $newstyle $event $text);

%do_on_event = ();		# output routines
$style = '';			# current style
$newstyle = '';			# new style if style changing
$event = '';			# start or end
$text = '';			# pending text
%symbol = ();			# symbol translations
%char = ();			# character translations
%info = ();			# info part of the document
%par_props = ();		# paragraph properties

###########################################################################
				# Specification of the callback interface
				# so you can easily reorder arguments
use constant SELF => 0;
use constant CONTROL => 1;
use constant ARG => 2;
use constant EVENT => 3;

###########################################################################
				# Automata states, control modes
my $IN_STYLESHEET = 0;		# inside or outside style table
my $IN_FONTTBL = 0;		# inside or outside font table
my $IN_TABLE = 0;

my %fonttbl;
my %stylesheet;
my %colortbl;
my @par = ();			# stack of paragraph properties
my @control = ();		# stack of control instructions
my $stylename = '';
my $cstylename = '';		# previous encountered style
my $cli = 0;			# current line indent value
my $styledef = '';

###########################################################################
				# output stack management
my @output_stack;
use constant MAX_OUTPUT_STACK_SIZE => 0; # 8 seems a good value
sub dump_stack {
  local($", $\) = ("\n") x 2;
  my $i = @output_stack;
  print STDERR "Stack size: $i";
  print STDERR map { $i-- . " |$_|\n" } reverse @output_stack;
}
my $nul_output_sub = sub {};
my $string_output_sub = sub { $output_stack[-1] .= $_[0]; };
sub output { 
  $output_stack[-1] .= $_[0] 
};
sub push_output {  
  if (MAX_OUTPUT_STACK_SIZE) {
    die "max size of the output stack exceeded" if @output_stack == MAX_OUTPUT_STACK_SIZE;
  }
  if ($_[0] eq 'nul') {
    *output = $nul_output_sub;
  } else {
    *output = $string_output_sub; 
  }
  push @output_stack, '';
}
sub pop_output {  pop @output_stack; }
my $flush_output_level = 2;
sub flush_output { 
  return unless @output_stack == $flush_output_level;
  my $content = $output_stack[-1]; 
  $output_stack[-1] = ''; 
  print $content 
}
###########################################################################
				# Trace management
use constant STYLESHEET_TRACE => 0; # If you want to see the stylesheet of the document
use constant TRACE => 0;	# General trace
use constant STACK_TRACE => 0; # 
use constant DEBUG => 0;

$| = 1 if TRACE or STACK_TRACE or DEBUG;
sub trace {
  #my(@caller) = (caller(1));
  #my $sub = (@caller)[3];
  #$sub =~ s/.*:://;
  #$sub = sprintf "%-12s", $sub;
  print STDERR ('_' x $#control . "@_\n");
}
$SIG{__DIE__} = sub {
  require Carp;
  Carp::confess;
} if DEBUG;

###########################################################################
				# Some generic routines
use constant DISCARD_CONTENT => 0;
sub discard_content {		
  my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  #trace "($_[CONTROL], $_[ARG], $_[EVENT])" if DISCARD_CONTENT;
  if ($_[ARG] eq "0") { 
    pop_output();
    $control[-1]->{"$_[CONTROL]1"} = 1;
  } elsif ($_[EVENT] eq 'start') { 
    push_output();
    $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
  } elsif ($_[ARG] eq "1") { # see above
    $cevent = 'start';
    push_output();
  } elsif ($_[EVENT] eq 'end') { # End of discard
    my $string = pop_output();
    if (length $string > 30) {
      $string =~ s/(.{1,10}).*(.{1,10})/$1 ... $2/;
    }
    trace "discard content of \\$control: $string" if DISCARD_CONTENT;
  } else {
    die "($_[CONTROL], $_[ARG], $_[EVENT])" if DISCARD_CONTENT;
  }
}


my %charset;
my $bulletItem;
sub define_charset {
  #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  no strict qw/refs/;
  eval {			# if not defined in RTF::Charsets
    %charset = %{"$_[CONTROL]"};
  };
  warn $@ if $@;
  $bulletItem = quotemeta($char{'periodcentered'});
}
sub do_on_info {		# 'info' content
  #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  my $string;
  if ($_[EVENT] eq 'start') { 
    push_output();
    $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
  } else {
    $string = pop_output();
    $info{"$_[CONTROL]$_[ARG]"} = $string;
  }
}
				# SYMBOLS
				# default mapping for symbols
%symbol = qw(
	     | |
	     _ _
	     : :
	     rdblquote "
	     ldblquote "
	     endash -
	     emdash -
	     bullet o
	     rquote '
	    );			# '
sub do_on_symbol { output $symbol{$_[CONTROL]} }
my %symbol_ctrl = 
  (
   'emdash' => \&do_on_symbol,
   'rquote' => \&do_on_symbol,
   'ldblquote' => \&do_on_symbol,
   'rdblquote' => \&do_on_symbol,
  );


				# TOGGLES
				# Many situations can occur:
				# {\<toggle> ...}
				# {\<toggle>0 ...}
				# \<control>\<toggle>
				# eg: \par \pard\plain \s19 \i\f4

use constant DO_ON_TOGGLE => 0;
sub do_on_toggle {
  return if $IN_STYLESHEET or $IN_FONTTBL;
  my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  trace "my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);" if DO_ON_TOGGLE;

  if ($_[ARG] eq "0") { 
    $cevent = 'end';
    trace "argument: |$_[ARG]| at line $.\n" if DO_ON_TOGGLE;
    $control[-1]->{"$_[CONTROL]1"} ; # register an END event
    if (defined (my $action = $do_on_event{$control})) {
      ($style, $event, $text) = ($control, 'end', '');
      &$action;
    } 
  } elsif ($_[EVENT] eq 'start') {
    $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
    
    if (defined (my $action = $do_on_event{$control})) {
      ($style, $event, $text) = ($control, 'start', '');
      trace "($style, $event, $text)\n" if DO_ON_TOGGLE;
      &$action;
    } 
    
  } else {			# END
    $cevent = 'start' if $_[ARG] eq "1"; # see above
    if (defined (my $action = $do_on_event{$control})) {
      ($style, $event, $text) = ($control, $cevent, '');
      &$action;
    } 
  }
}
# Just an example, do the same thing 
# for all RTF toggles
my %toggle_ctrl = 
  (			
   'b' => \&do_on_toggle,
   'i' => \&do_on_toggle,
   'ul' => \&do_on_toggle,
   'sub' => \&do_on_toggle,
   'super' => \&do_on_toggle,
  );

				# FLAGS
use constant DO_ON_FLAG => 0;
sub do_on_flag {
  #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
  die if $_[ARG];			# no argument by definition
  trace "$_[CONTROL]" if DO_ON_FLAG;
  $par_props{$_[CONTROL]} = 1;
}
my %flag_ctrl =			# Just an example, do the same thing 
  (				# for all RTF flags
   'ql' => \&do_on_flag,
   'qr' => \&do_on_flag,
   'qc' => \&do_on_flag,
   'qj' => \&do_on_flag,

   'ansi' => \&define_charset,	# The default
   'mac' => \&define_charset,	# Apple Macintosh
   'pc' => \&define_charset,	# IBM PC code page 437 
   'pca' => \&define_charset,	# IBM PC code page 850

   'pict' => \&discard_content,	#
   'xe'  => \&discard_content,	# index entry
   #'v'  => \&discard_content,	# hidden text
  );

sub do_on_destination {
  trace "currently do nothing";
}
my %destination_ctrl =
  (
  );

sub do_on_value {
  trace "currently do nothing";
}
my %value_ctrl =
  (
  );

use vars qw(%do_on_control);
%do_on_control = 
  (
   %flag_ctrl,
   %value_ctrl,
   %symbol_ctrl,
   %toggle_ctrl,
   %destination_ctrl,

   'plain' => sub {
     unless (@control) {
       die "\@control stack is empty";
     }
     my @keys = keys %{$control[-1]};
     foreach my $control (@keys) {
       if (defined (my $action = $do_on_event{$control})) {
	 ($style, $event, $text) = ($control, 'end', '');
	 &$action;
       } 
     }
   },
   'rtf' => \&discard_content,	# destination
   'info' => sub {		# {\info {...}}
     if ($_[EVENT] eq 'start') { 
       push_output('nul');
       $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       pop_output();
     }
   },
				# INFO GROUP
   # Other informations:
   # {\printim\yr1997\mo11\dy3\hr11\min5}
   # {\version3}{\edmins1}{\nofpages3}{\nofwords1278}{\nofchars7287}
   # {\*\company SONOVISION-ITEP}{\vern57443}
   'title' => \&do_on_info,	# destination
   'author' => \&do_on_info,	# destination
   'revtim' => \&do_on_info,	# destination
   'creatim' => \&do_on_info,	# destination, {\creatim\yr1996\mo9\dy18\hr9\min17}
   'yr' => sub { output "$_[ARG]-" }, # value
   'mo' => sub { output "$_[ARG]-" }, # value
   'dy' => sub { output "$_[ARG]-" }, # value
   'hr' => sub { output "$_[ARG]-" }, # value
   'min' => sub { output "$_[ARG]" }, # value

				# binary data
   'bin' => sub { $_[SELF]->read_bin($_[ARG]) }, # value

				# Color table - destination
   'colortbl' => \&discard_content,
				# Font table - destination
   'fonttbl' => sub {
     #trace "$#control $_[CONTROL] $_[ARG] $_[EVENT]";
     if ($_[EVENT] eq 'start') { 
       $IN_FONTTBL = 1 ;
       push_output('nul');
       $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       $IN_FONTTBL = 0 ;
       pop_output();
     }
   },
				# file table - destination
   'filetbl' => sub {
     #trace "$#control $_[CONTROL] $_[ARG] $_[EVENT]";
     if ($_[EVENT] eq 'start') { 
       push_output('nul');
       $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       pop_output();
     }
   },

   'f', sub {			
     #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);

     use constant FONTTBL_TRACE => 0; # if you want to see the fonttbl of the document
     if ($IN_FONTTBL) {
       if ($_[EVENT] eq 'start') {
	 push_output();
	 $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
       } else {
	 my $fontname = pop_output;
	 my $fontdef = "$_[CONTROL]$_[ARG]";
	 if ($fontname =~ s/\s*;$//) {
	   trace "$fontdef => $fontname" if FONTTBL_TRACE;
	   $fonttbl{$fontdef} = $fontname;
	 } else {
	   warn "can't analyze $fontname";
	 }
       }
       return;
     }

     return if $styledef;	# if you have already encountered an \sn
     $styledef = "$_[CONTROL]$_[ARG]";

     if ($IN_STYLESHEET) {	# eg. \f4 => Normal;
       if ($_[EVENT] eq 'start') {
	 #trace "start $_[CONTROL]$_[ARG]" if STYLESHEET;
	 push_output();
	 $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
       } else {
	 my $stylename = pop_output;
	 #trace "end\n $_[CONTROL]" if STYLESHEET;
	 if ($stylename =~ s/\s*;$//) {
	   trace "$styledef => $stylename" if STYLESHEET_TRACE;
	   $stylesheet{$styledef} = $stylename;
	 } else {
	   warn "can't analyze $stylename";
	 }
       }
       $styledef = '';
       return;
     }

     $stylename = $stylesheet{"$styledef"};
     return unless $stylename;

     if ($cstylename ne $stylename) { # notify a style changing
       if (defined (my $action = $do_on_event{'style_change'})) {
	 ($style, $newstyle) = ($cstylename, $stylename);
	 &$action;
       } 
     }

     $cstylename = $stylename;
   },
				# 
				# Style processing
				# 
   'stylesheet' => sub {
     #trace "stylesheet $#control $_[CONTROL] $_[ARG] $_[EVENT]";
     if ($_[EVENT] eq 'start') { 
       $IN_STYLESHEET = 1 ;
       push_output('nul');
       $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       $IN_STYLESHEET = 0;
       pop_output;
     }
   },
   's', sub {
     my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
     $styledef = "$_[CONTROL]$_[ARG]";

     if ($IN_STYLESHEET) {
       if ($_[EVENT] eq 'start') {
	 push_output();
	 $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
       } else {
	 my $stylename = pop_output;
	 warn "empty stylename" and return if $stylename eq '';
	 if ($stylename =~ s/\s*;$//) {
	   trace "$styledef => $stylename|" if STYLESHEET_TRACE;
	   $stylesheet{$styledef} = $stylename;
	   $styledef = '';
	 } else {
	   warn "can't analyze style name: '$stylename'";
	 }
       }
       return;
     }

     $stylename = $stylesheet{"$styledef"};

     if ($cstylename ne $stylename) {
       if (defined (my $action = $do_on_event{'style_change'})) {
	 ($style, $newstyle) = ($cstylename, $stylename);
	 &$action;
       } 
     }

     $cstylename = $stylename;
   },
				# a very minimal table processing
   'trowd' => sub {		# row start
     use constant TABLE_TRACE => 0;
     #print STDERR "=>Beginning of ROW\n";
     unless ($IN_TABLE) {
       $IN_TABLE = 1;
       push_output();		# table content
       push_output();		# row  sequence
       push_output();		# cell sequence
       push_output();		# cell content
     }
   },
   'intbl' => sub {
     $par_props{'intbl'} = 1;
     unless ($IN_TABLE) {
       $IN_TABLE = 1;
       push_output();
       push_output();
       push_output();
       push_output();
     }
   },
   'row' => sub {		# row end
     $text = pop_output;
     $text = pop_output . $text;
     if (defined (my $action = $do_on_event{'cell'})) {
       $event = 'end';
       trace "row $event $text\n" if TABLE_TRACE;
       &$action;
     } 
     $text = pop_output;
     if (defined (my $action = $do_on_event{'row'})) {
       $event = 'end';
       trace "row $event $text\n" if TABLE_TRACE;
       &$action;
     } 
     push_output();
     push_output();
     push_output();
   },
   'cell' => sub {		# end of cell
     trace "process cell content: $text\n" if TABLE_TRACE;
     $text = pop_output;
     if (defined (my $action = $do_on_event{'par'})) {
       ($style, $event,) = ('par', 'end',);
       &$action;
     } else {
       warn "$text";;
     }
     $text = pop_output;
     if (defined (my $action = $do_on_event{'cell'})) {
       $event = 'end';
       trace "cell $event $text\n" if TABLE_TRACE;
       &$action;
     } 
 				# prepare next cell
     push_output();
     push_output();
     trace "\@output_stack in table: ", @output_stack+0 if STACK_TRACE;
   },
   'par' => sub {		# END OF PARAGRAPH
     use constant STYLE_TRACE => 0; # 
     #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
     trace "($_[CONTROL], $_[ARG], $_[EVENT])" if STYLE_TRACE;
     if ($IN_TABLE and not $par_props{'intbl'}) { # End of Table
       $IN_TABLE = 0;
       my $next_text = pop_output; # next paragraph content
       
       $text = pop_output;
       $text = pop_output . "$text";
       if (defined (my $action = $do_on_event{'cell'})) { # end of cell
	 $event = 'end';
	 trace "cell $event $text\n" if TABLE_TRACE;
	 &$action;
       } 
       $text = pop_output;
       if (defined (my $action = $do_on_event{'row'})) { # end of row
	 $event = 'end';
	 trace "row $event $text\n" if TABLE_TRACE;
	 &$action;
       } 
       $text = pop_output;
       if (defined (my $action = $do_on_event{'table'})) { # end of table
	 $event = 'end';
	 trace "table $event $text\n" if TABLE_TRACE;
	 &$action;
       } 
       push_output();	       
       trace "end of table ($next_text)\n" if TABLE_TRACE;
       output($next_text);
     } else {
       trace "\@output_stack in table: ", @output_stack+0 if STACK_TRACE;
       #push_output();	
     }
				# paragraph style
     if ($cstylename ne '') {	# end of previous style
       $style = $cstylename;
     } else {
       $cstylename = $style = 'par'; # no better solution
     }
       
     if ($par_props{intbl}) {	# paragraph in tbl
       trace "process cell content: $text\n" if TABLE_TRACE;
       if (defined (my $action = $do_on_event{$style})) {
	 ($style, $event, $text) = ($style, 'end', pop_output);
	 &$action;
       } elsif (defined (my $action = $do_on_event{'par'})) {
	 ($style, $event, $text) = ('par', 'end', pop_output);
	 &$action;
       } else {
	 warn;
       }
       push_output(); 
     } elsif (defined (my $action = $do_on_event{$style})) {
       ($style, $event, $text) = ($cstylename, 'end', pop_output);
       &$action;
       flush_output();
       push_output(); 
     } elsif (defined (my $action = $do_on_event{'par'})) {
       ($style, $event, $text) = ('par', 'end', pop_output);
       &$action;
       flush_output();
       push_output(); 
     } else {
       trace "no definition for '$style' in %do_on_event\n" if STYLE_TRACE;
       flush_output();
       push_output(); 
     }
     $cli = $par_props{'li'};
     $styledef = '';
     $par_props{'bullet'} = $par_props{'number'} = $par_props{'tab'} = 0; # 
   },
				# Resets to default paragraph properties
				# Stop inheritence of paragraph properties
   'pard' => sub {		
     foreach (qw(qj qc ql qr intbl li)) {
       $par_props{$_} = 0;
     }
     $cstylename = '';		# ???
   },
				# paragraph characteristics
				# What is the Type of the list items?
   'pntext' => sub {
     #my($control, $arg, $cevent) = ($_[CONTROL], $_[ARG], $_[EVENT]);
     #if ($_[ARG] == 0) { $cevent = 'end' }; # ???
     #trace "pntext: ($_[CONTROL], $_[ARG], $_[EVENT])";
     my $string;
     if ($_[EVENT] eq 'start') { 
       push_output();
       $control[-1]->{"$_[CONTROL]$_[ARG]"} = 1;
     } else {
       $string = pop_output();
       $par_props{"$_[CONTROL]$_[ARG]"} = $string;
       #trace qq!pntext: $par_props{"$_[CONTROL]$_[ARG]"} = $string!;

       if ($string =~ s/^$bulletItem//o) { # Heuristic rules
	 $par_props{'bullet'} = 1;
       } elsif ($string =~ s/(\d+)[.]//) { # e.g. <i>1.</i>
	 $par_props{'number'} = $1;
       } else {
	 # letter???
       }
     }
   },
   #'tab' => sub { $par_props{'tab'} = 1 }, # special char

   'li' => sub {		# line indent - value
     use constant LI_TRACE => 0;
     my $indent = $_[ARG];
     $indent =~ s/^-//;
     trace "line indent: $_[ARG] -> $indent" if LI_TRACE;
     $par_props{'li'} = $indent;
   },
  );
###########################################################################
				# 
				# Callback methods
				# 
use constant DESTINATION_TRACE => 0;
sub destination {
  #my $self = shift;
  return unless DESTINATION_TRACE;
  my $destination = shift; 
  $destination =~ s/({\\[*]...).*(...})/$1 ... $2/ or die "invalid destination";
  trace "skipped destination: $destination" if DESTINATION_TRACE;
}

use constant GROUP_START_TRACE => 0;
sub groupStart {
  my $self = shift;
  trace "" if GROUP_START_TRACE;
  push @par, { %par_props };
  push @control, {};		# hash of controls
}
use constant GROUP_END_TRACE => 0;
sub groupEnd {
  %par_props = %{pop @par};
  $cstylename = $par_props{'stylename'}; # the current style 
  no strict qw/refs/;
  foreach my $control (keys %{pop @control}) { # End Event!
    $control =~ /([^\d]+)(\d+)?/;
    trace "($#control): $1-$2" if GROUP_END_TRACE;
    &{"Action::$1"}($_[0], $1, $2, 'end'); # sub associated to $1 is already defined
  }
}
use constant TEXT_TRACE => 0;
sub text { 
  trace "$_[1]" if TEXT_TRACE;
  output($_[1]);
}
sub char {			
  my $name;
  my $char;
  if (defined($char = $char{$name = $charset{$_[1]}}))  {
    output "$char";
  } else {
    output "$name";	     
  }
}
sub symbol {
  if (defined(my $sym = $symbol{$_[1]}))  {
    output "$sym";
  } else {
    output "$_[1]";		# as it
  }
}

sub parseStart {
  my $self = shift;

  # some initializations
  %info = ();
  %fonttbl = ();
  %colortbl = ();
  %stylesheet = ();

  push_output();
  push_output();

  if (defined (my $action = $do_on_event{'document'})) {
    $event = 'start';
    &$action;
  } 
}
sub parseEnd {
  my $self = shift;
  my $action = '';
  
  trace "parseEnd \@output_stack: ", @output_stack+0 if STACK_TRACE;

  if (defined ($action = $do_on_event{'document'})) {
    ($style, $event, $text) = ($cstylename, 'end', pop_output);
    &$action;
  } 
  print pop_output;
  if (@output_stack) {
    my $string = pop_output;
    warn "unanalysed string: '$string'" if $string;
  }
}
use vars qw(%not_processed);
END {
  if (@control) {
    trace "Stack not empty: ", @control+0;
  }
  if ($LOG_FILE) {
    select STDERR;
    unless (open LOG, "> $LOG_FILE") {
      print qq^$::BASENAME: unable to output data to "$LOG_FILE"$::EOM^;
      return 0;
    }
    select LOG;
    my($key, $value) = ('','');
    while (my($key, $value) = each %not_processed) {
      printf LOG "%-20s\t%3d\n", "$key", "$value";
    }
    close LOG;
    print STDERR qq^See Informations in the "$LOG_FILE" file\n^;
  }
}
1;
__END__

