# Sonovision-Itep, Verdret 1998
use strict;
package RTF::HTML::Output;

use RTF::Control;
@RTF::HTML::Output::ISA = qw(RTF::Control);

#               APPLICATION INTERFACE, 
#               COULD NOTABLY EVOLVE  !!!

# todo:
# - a table oriented output specification could be nice

# Events (examples):
# ul, b, i
# document : 
# - start: 
# - end: 
# table 
# row 
# cell 

# Symbol exported by the RTF::Ouptut module:
# %info: informations of the {\info ...}
# %par_props: paragraph properties
# $style: name of the current style or pseudo-style
# $event: start and end on the 'document' event
# $text: text associated to the current style
# %char: character translations
# %symbol: symbol translations
# %do_on_event: output routines
# output(): a stack oriented output routine (don't use print())

# See examples in the following code for a specific stylesheet
# Now you can define your own rules...

				# Some generic parameters
				# define character mappings
				# some values could be found in HTML::Entities.pm
				# or redefine the char() method
				# Examples: 
%char = qw(
	   periodcentered *
	   copyright      ©
	   registered     ®
	   section        §
	   paragraph      ¶
	   nobrkspace     \240
	   odieresis      ö
	   idieresis      &iuml
	   egrave         &egrave;
	   agrave         &agrave;
	   eacute         &eacute;
	   ecirc          &ecirc;
	  );  
				# add value to %symbol
$symbol{'~'} = '&nbsp;'; 
$symbol{'ldblquote'} = '&laquo;';
$symbol{'rdblquote'} = '&raquo;';

sub text {			# callback redefinition
  my $text = $_[1];
  $text =~ s/</&lt;/g;	
  $text =~ s/>/&gt;/g;	
  output($text);
}

my $N = "\n"; # Pretty-printing
#my @listStack = ();

				# some parameters
my $TITLE_FLAG = 0;
my $LANG = 'fr';
my $TABLE_BORDER = 1;
my %P_ALIGN = qw(
		 qc CENTER
		 ql LEFT
		 qr RIGHT
		 qj LEFT
		);

my @ELT_ATT;			# HTML element attributes
%do_on_event = 
  (
   'document' => sub {		# Special action
     if ($event eq 'start') {
       output qq@<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">$N<html>$N@;
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
     output "$N<tr valign='top'>$text</tr>$N";
   },
   'cell' => sub {
     output "<td>$text</td>$N";
   },
   'Normal' => sub {
     return output($text) unless $text =~ /\S/;
     if ($par_props{'bullet'}) {	# Heuristic rules
       $style = 'LI';
     } elsif ($par_props{'number'}) { 
       $style = 'LI';
     } else {
       $style = 'p';
       foreach (qw(qj qc ql qr)) {
	 if ($par_props{$_}) {
	   push @ELT_ATT, "ALIGN=$P_ALIGN{$_}";
	 }
       }
       #print STDERR "Normal par props: @ELT_ATT\n";
     }
     output "<$style @ELT_ATT>$text</$style>\n";
     @ELT_ATT = ();
   },
   'b' => sub {			
     $style = 'b';
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
   'i' => sub {
     $style = 'i';
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
   'par' => sub {	
     my $m;
     if ($par_props{'bullet'}) {	# Heuristic rules
       $style = 'LI';
     } elsif ($par_props{'number'}) { 
       $style = 'LI';
     } else {
       $style = 'p';
       foreach (qw(qj qc ql qr)) {
	 if ($par_props{$_}) {
	   push @ELT_ATT, "ALIGN=$P_ALIGN{$_}";
	 }
       }
       #print STDERR "par props: @ELT_ATT\n";
     }
     output "$N<$style @ELT_ATT>$text</$style>$N";
     @ELT_ATT = ();
   },
  );
1;
__END__
