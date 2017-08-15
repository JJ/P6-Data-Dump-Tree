#!/usr/bin/env perl6

use Test ;
use Data::Dump::Tree ;
use Data::Dump::Tree::DescribeBaseObjects ;

plan 3 ;

class HasNothing
{

#method ddt_get_header { ('', '.' ~ self.^name) } # use default
method ddt_get_elements 
{ 
	[ 
	('nothing', '', Data::Dump::Tree::Type::Nothing),
	('text', ' ', 'text'),
	]
}

#class
}

my $d = Data::Dump::Tree.new(:!color, does => (DDTR::AsciiGlyphs,)) ;
my $dump = $d.ddt: :get, HasNothing.new() ;

is $dump.lines.elems, 3, '3 lines output' ;
like $dump, /nothing/, 'nothing as no value' ;
like $dump, /\.Str/, 'something has value' ;


