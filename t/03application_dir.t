#!/usr/bin/perl

# We're checking that application_dir returns sensibly.

use strict;
use RTF::Control;

use RTF::TEXT::Converter;

use Test::More tests => 2;



{ 

	my $object = RTF::TEXT::Converter->new();
	
	my $path = $object->application_dir;
	
	diag("Checking in $path/");
	
	ok( (-f $path . '/char_map' ), 'application_dir() works for RTF::TEXT::Converter' );

}

{ 

	my $object = RTF::Control->new( -confdir => 'asdfasdf' );
	is( $object->application_dir, 'asdfasdf', '-confdir to set application_dir works' );

}
