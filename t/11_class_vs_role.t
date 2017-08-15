#!/usr/bin/env perl6

use Test ;
plan 7 ;

use Data::Dump::Tree ;
use Data::Dump::Tree::DescribeBaseObjects ;

my $d = Data::Dump::Tree.new does DDTR::AsciiGlyphs ;


class UseDefault
{
has $.from_default = 'public' ;
has $!from_default_private = 'private';
}

my $dump = $d.ddt: :get, UseDefault.new, color => False ;
like $dump, /from_default \s  \=/, 'Shy first role' or diag $dump ;
like $dump, /from_default_private/, 'Shy first role' or diag $dump ;
is $dump.lines.elems, 3, '3 lines dump' ;

class C 
{
has $!a = 1 ;
has $.b = 1 ;

method ddt_get_elements { [ 'class', ' = ', $!a ],  }
}

$dump = $d.ddt: :get, C.new ;

like $dump, /class/, 'use class' ;
is $dump.lines.elems, 2, '2 lines dump' ;


role OverrideClassGetElements { multi method get_elements(C $c) {['role', ' = ', 'role' ],} }

$d does OverrideClassGetElements ;
$dump = $d.ddt: :get, C.new ;

like $dump, /role/, 'use role' ;
is $dump.lines.elems, 2, '2 lines dump' ;


