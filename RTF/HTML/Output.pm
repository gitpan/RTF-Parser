# sonovision-Itep, Verdret 1998-1999
use strict;
package RTF::HTML::Output;

use RTF::Control;
@RTF::HTML::Output::ISA = qw(RTF::Control);

use constant TRACE => 0;
my $START_NEW_PARA = 1;		# some actions to do at the beginning of a new para

# APPLICATION INTERFACE - COULD NOTABLY EVOLVE !!!

# Symbol exported by the RTF::Ouptut module:
# %info: informations of the {\info ...}
# %par_props: paragraph properties
# $style: name of the current style or pseudo-style
# $event: start and end on the 'document' event
# $text: text associated to the current style
# %symbol: symbol translations
# %do_on_control: routines associated to RTF controls
# %do_on_event: routines associated to events
# output(): a stack oriented output routine (don't use print())

# If you have an &<entity>; in your RTF document and if
# <entity> is a character entity, you'll see "&<entity>;" in the RTF document
# and the corresponding glyphe in the HTML document
# I don't know what is the best way to redefine a control callback? 
# - as a method redefinition
# - $Control::do_on_control{control_word} = sub {}; 
# or when %do_on_control is exported write:
$do_on_control{'ansi'} =	# callcack redefinition
  sub {
    # RTF: \'[0-9a-f][0-9a-f]
    # HTML: &#<decimal value>;
    my $charset = $_[CONTROL];
    my $charset_file = $_[SELF]->application_dir() . "/$charset";
    open CHAR_MAP, "$charset_file"
      or die "unable to open the '$charset_file': $!";

    my %charset = (		# general rule
		   map({ sprintf("%02x", $_) => "&#$_;" } (0..255)),
				# and some specific defs
		   map({ s/^\s+//; split /\s+/ } (<CHAR_MAP>))
		  );
    *char = sub { 
      my $char_props;
      if ($START_NEW_PARA) {	# !!! do the same thing in the symbol() and char() methods
	$char_props = $_[SELF]->force_char_props('start');
	$START_NEW_PARA = 0;
      } else {
	$char_props = $_[SELF]->process_char_props();
      }
      output $char_props . $charset{$_[1]}
    } 
  };

				# symbol processing
				# RTF: \~
				# named chars
				# RTF: \ldblquote, \rdblquote
$symbol{'~'} = '&nbsp;';
$symbol{'tab'} = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
$symbol{'ldblquote'} = '&laquo;';
$symbol{'rdblquote'} = '&raquo;';
$symbol{'line'} = '<br>';
sub symbol {			
  my $char_props;
  if ($START_NEW_PARA) {	# !!! do the same thing in the symbol() and char() methods
    $char_props = $_[SELF]->force_char_props('start');
    $START_NEW_PARA = 0;
  } else {
    $char_props = $_[SELF]->process_char_props();
  }
  if (defined(my $sym = $symbol{$_[1]}))  {
    output $char_props . $sym;
  } else {
    output $char_props . $_[1];		# as it
  }
}
				# Text
				# certainly do the same thing with the char() method
sub text {			# parser callback redefinition
  my $text = $_[1];
  my $char_props;
  if ($START_NEW_PARA) {	
    $char_props = $_[SELF]->force_char_props('start');
    $START_NEW_PARA = 0;
  } else {
    $char_props = $_[SELF]->process_char_props();
  }
  $text =~ s/</&lt;/g;	
  $text =~ s/>/&gt;/g;	
  output("$char_props$text");
}

###########################################################################
my $N = "\n"; # Pretty-printing
				# some output parameters
my $TITLE_FLAG = 0;
my $LANG = 'en';
my $TABLE_BORDER = 1;
my %P_ALIGN = qw(
		 qc CENTER
		 ql LEFT
		 qr RIGHT
		 qj LEFT
		);

# Events (examples):
# ul, b, i
# document : 
# - start: 
# - end: 
# table 
# row 
# cell 
%do_on_event = 
  (
   'document' => sub {		# Special action
     if ($event eq 'start') {
       output qq@<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN" []>$N<html>$N<body>$N@;
     } else {
       my $author = $info{author};
       my $creatim = $info{creatim};
       my $revtim = $info{revtim};
       #while (@listStack) {
       #$style = pop @listStack;
       #output "</$style>$N";
       #}
       $style = 'p';

       if ($LANG eq 'fr') {
	 output "<$style><b>Auteur</b> : $author</$style>\n" if $author;
	 output "<$style><b>Date de création</b> : $creatim</$style>\n" if $creatim;
	 output "<$style><b>Date de modification</b> : $revtim</$style>\n" if $revtim;
       } else {			# Default
	 output "<$style><b>Author</b> : $author</$style>\n" if $author;
	 output "<$style><b>Creation date</b>: $creatim</$style>\n" if $creatim;
	 output "<$style><b>Modification date</b>: $revtim</$style>\n" if $revtim;
       }
       output "</body>\n</html>\n";
     }
   },
				# Table processing
   'table' => sub {
     $TABLE_BORDER ? output "<table BORDER>$N$text</table>$N"
       :
	 output "<table>$N$text</table>$N";
   },
   'row' => sub {
     my $char_props = $_[SELF]->force_char_props('end');
     output "$N<tr valign='top'>$text$char_props</tr>$N";
   },
   'cell' => sub {
     my $char_props = $_[SELF]->force_char_props('end');
     output "<td>$text$char_props</td>$N";
   },
				# Paragraph styles
   'Normal' => sub {		# A rule for the 'Normal' style
     return output($text) unless $text =~ /\S/;
     #warn "the 'Normal' style should be redefined";
     $START_NEW_PARA = 1;
   },
   'par' => sub {		# Default rule: if no entry for a paragraph style
     my ($tag_start, $tag_end);
     if ($par_props{'bullet'}) {	# Heuristic rules
       $tag_start = $tag_end = 'LI';
     } elsif ($par_props{'number'}) { 
       $style = 'LI';
       $tag_start = $tag_end = 'LI';
     } else {
       $tag_start = $tag_end = 'p';
       foreach (qw(qj qc ql qr)) {
	 if ($par_props{$_}) {
	   $tag_start .= " ALIGN=$P_ALIGN{$_}";
	 }
       }
     }
     use constant SHOW_LINE => 0;
     $_[SELF]->trace("$tag_start-$tag_end: $text") if TRACE;
     my $char_props = $_[SELF]->force_char_props('end');
     if (SHOW_LINE) {
       output "$N<$tag_start>[$.]$text$char_props</$tag_end>$N";
     } else {
       output "$N<$tag_start>$text$char_props</$tag_end>$N";
     }
     $START_NEW_PARA = 1;
   },
				# Char styles
   'b' => sub {			
     $style = 'b';
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'i' => sub {
     $style = 'i';
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'ul' => sub {		
     $style = 'em';
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'sub' => sub {
     $style = 'sub';
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
   'super' => sub {
     $style = 'sup';
     if ($event eq 'end') {
       output "</$style>";
     } else {
       output "<$style>";
     }
   },
  );
1;
__END__
