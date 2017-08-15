#!/usr/bin/env perl6

use Test ;
plan 2 ;

use Data::Dump::Tree ;
use Data::Dump::Tree::ExtraRoles ;
use Data::Dump::Tree::DescribeBaseObjects ;

my regex header { \s* '[' \w+ ']' \h* \n+ }
my regex identifier  { \w+ }
my regex kvpair { \s* <key=identifier> '=' <value=identifier> \n+ }
my regex section {
    <header>
    <kvpair>*
}

my $contents = q:to/EOI/;
    [passwords]
        jack=password1
        joy=muchmoresecure123
    [quotas]
        jack=123
        joy=42
EOI

my $m = $contents ~~ /<section>*/ ;

my $d = Data::Dump::Tree.new: :does[DDTR::MatchDetails, DDTR::PerlString, DDTR::AsciiGlyphs] ;

my $dump_5 = $d.ddt: :get, $m, :title<roles via new>, :width(115), :!color ;
is($dump_5.lines.elems, 28, '28 lines of section parsing, roles via new() ') or diag $dump_5 ;

# -------------------------------

$m = $contents ~~ /<section>*/ ;

my $d2 = Data::Dump::Tree.new does DDTR::AsciiGlyphs ;

my $dump_6 = $d2.ddt: :get, $m, :title<roles via config>, :width(115), :does[DDTR::MatchDetails, DDTR::PerlString] ;

is($dump_6.lines.elems, 28, '28 lines of section parsing, roles via config') or diag $dump_6 ;

