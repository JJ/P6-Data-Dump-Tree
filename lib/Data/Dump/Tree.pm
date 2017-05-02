
use Data::Dump::Tree::AnsiColor ;
use Data::Dump::Tree::Enums ;
use Data::Dump::Tree::DescribeBaseObjects ;

class Data::Dump::Tree does DDTR::DescribeBaseObjects
{
has $.colorizer = AnsiColor.new() ;
method is_ansi { $!colorizer.is_ansi }

my %default_colors =
	<
	ddt_address blue     perl_address yellow  link   green
	header      magenta  key         cyan     binder cyan 
	value       reset    wrap        yellow

	gl_0 242  gl_1 yellow  gl_2 green gl_3 red  gl_4 blue

	kb_0 178   kb_1 172 
	kb_2 33    kb_3 27
	kb_4 175   kb_5 169      
	kb_6 34    kb_7 28
	kb_8 160   kb_9 124 
	> ;

has $.title ;
has Bool $.caller is rw = False ;

has Bool $.color is rw = True ;
has %.colors ;

has $.color_glyphs ;
has @.glyph_colors ;
has @.glyph_colors_cycle ; 

has $.color_kbs ;
has @.kb_colors ;
has @.kb_colors_cycle ; 

has @.header_filters ;
has @.elements_filters ;
has @.footer_filters ;

has %!rendered ;
has %!element_names ;

has $!address ;

has DDT_Address_Display $.display_address is rw = DDT_Address_Display::DDT_DISPLAY_CONTAINER ;

has Bool $.display_info is rw = True ;
has Bool $.display_type is rw = True ;
has Bool $.display_perl_address is rw = False ; 

has %.paths ;
has Bool $.keep_paths is rw = False ;

has $.width is rw ; 

has $.max_depth is rw = -1 ;
has Bool $.max_depth_message is rw = True ;

has @!renderings ;
method get_renderings() { @!renderings }

method new(:@does, *%attributes)
{
my %colors = %attributes<colors> // (), %default_colors ;

my $object = self.bless(|%attributes);

for @does // () -> $role { $object does $role }

if $object.is_ansi 
	{ $object does DDTR::AnsiGlyphs } 
else
	{ $object does DDTR::AsciiGlyphs}

unless $object.display_info 
	{
	$object.display_type = False ;
	$object.display_address = DDT_DISPLAY_NONE ;
	}

$object 
}

sub dump($s, *%options) is export { say get_dump($s, |%options) }
sub get_dump($s, *%options) is export { Data::Dump::Tree.new(|%options).get_dump($s)}
sub get_dump_lines($s, *%options) is export { Data::Dump::Tree.new(|%options).get_dump_lines($s)}

method dump($s, *%options) { say self.get_dump($s, |%options) }

method get_dump($s, *%options)
{
self.get_dump_lines($s, |%options).join("\n") ~ "\n"
}

method get_dump_lines($s, *%options)
{
# roles can be passed in new() or as options to dump
# make a clone so we do not pollute the object

my $clone = self.clone(|%options) ;

for %options<does> // () -> $role { $clone does $role } 

if %options<display_info> 
	{
	$clone.display_type = False ;
	$clone.display_address = DDT_DISPLAY_NONE ; 
	}

$clone.render_root($s) ;
$clone.get_renderings() ;
}

method reset
{
$!address = 0 ;
@!renderings = () ;
%!rendered = () ;
%.paths = () ;

$!colorizer.set_colors(%(|%default_colors, |$.colors), $.color) ;

if $.color_glyphs 
	{
	unless @.glyph_colors.elems
		{
		@.glyph_colors.append:  "gl_$_" for ^5 ;
		}
	}
else
	{
	@.glyph_colors = < gl_0 > ;
	}
@!glyph_colors_cycle = |@.glyph_colors xx  * ;

unless @.kb_colors.elems
	{
	@.kb_colors.append:  "kb_$_" for 0 ..10 ;
	}
@!kb_colors_cycle = |@.kb_colors xx  * ; 

$.width //= %+(qx[stty size] ~~ /\d+ \s+ (\d+)/)[0] ; 
}

method render_root($s)
{
$.reset ;

my (%glyphs, $width) := $.get_level_glyphs(0, True) ; 
my ($v, $f, $final, $want_address) = 
	$s.WHAT =:= Mu
		?? ('', '.Mu', DDT_FINAL ) 
		!! self.get_element_header($s) ;

self.render_element_structure(
	(self.get_title, '', $s, []),
	0,
	($final ?? 0 !! $width, '', '', %glyphs<multi_line>, '', ''),
	'') ;
}

method render_element_structure($element, $current_depth, @glyphs, $head_glyph)
{
my ($final, $rendered, $s, $continuation_glyph) := 
	$.render_element($element, $current_depth, @glyphs, $head_glyph) ;

self.render_non_final($s, $current_depth, $continuation_glyph) unless ($final || $rendered) ;

@!footer_filters and $s.WHAT !=:= Mu and 
	$.filter_footer($s, ($current_depth, $continuation_glyph, @!renderings))  ;
}

method render_non_final($s, $current_depth, $continuation_glyph)
{
my (@sub_elements, %glyphs) := $.get_sub_elements($s, $current_depth, $continuation_glyph) ;

for @sub_elements Z 0..* -> ($sub_element, $index)
	{
	self.render_element_structure(
		$sub_element,
		$current_depth + 1,
		self.get_element_glyphs(%glyphs, $index == @sub_elements.end),
		$continuation_glyph,
		) ;
	}
}

method render_element($element, $current_depth, @glyphs, $head_glyph)
{
my ($k, $b, $s, $path) = $element ;

my ($glyph_width, $glyph, $continuation_glyph, $multi_line_glyph, $empty_glyph, $filter_glyph) = @glyphs ;
($glyph, $continuation_glyph, $filter_glyph).map: { $_ = $head_glyph ~ $_ } ; 

my $width = $!width - ($glyph_width * ($current_depth + 1)) ;

my ($v, $f, $final, $want_address) ;

($v, $f, $final, $want_address) = 
	$s.WHAT =:= Mu
		?? ('', '.Mu', DDT_FINAL ) 
		!! self.get_element_header($s) ;

$f ~= ':U' unless $s.defined ;
$f = '' unless $.display_type ; 
 
$final //= DDT_NOT_FINAL ;


if $.display_address == DDT_DISPLAY_NONE | DDT_DISPLAY_ALL 
	{
	$want_address = True ;
	}
elsif $.display_address == DDT_DISPLAY_CONTAINER 
	{
	$want_address //= ! $final ;
	}

my ($address, $rendered) =
	$s.WHAT !=:= Mu
		?? $want_address ?? self!get_address($s) !! (Nil, False)
		!! (Nil, True) ;

$address = Nil if $.display_address == DDT_DISPLAY_NONE ;


my $s_replacement ;
@!header_filters and $s.WHAT !=:= Mu and  
	$.filter_header($s_replacement, $s, ($current_depth, $path, $filter_glyph, @!renderings), ($k, $b, $v, $f, $final, $want_address)) ;

$s_replacement ~~ Data::Dump::Tree::Type::Nothing and return(True, True, $s, $continuation_glyph) ;
$s = $s_replacement.defined ?? $s_replacement !! $s ;

$multi_line_glyph = $empty_glyph if $final ;

# perl stringy $v if role is on
($v, $, $) = self.get_header($v) if $s !~~ Str ;

my ($kvf, @ks, @vs, @fs) := self!split_entry($current_depth, $width, $k, $b, $glyph_width, $v, $f, $address) ;

if $kvf.defined
	{
	@!renderings.append: $glyph ~ $kvf ;
	}
else
	{
	@!renderings.append: $glyph ~ (@ks.shift if @ks) ; 
	@!renderings.append: @ks.map: { $continuation_glyph ~ $_} ; 
	@!renderings.append: @vs.map: { $continuation_glyph ~ $multi_line_glyph ~ $_} ; 
	@!renderings.append: @fs.map: { $continuation_glyph ~ $multi_line_glyph ~ $_} unless $.display_info == False ; 
	}

$final, $rendered, $s, $continuation_glyph
}

method get_sub_elements($s, $current_depth, $continuation_glyph)
{
my (%glyphs, $) := $.get_level_glyphs($current_depth) ; 

my @sub_elements ;

if $current_depth + 1 != $.max_depth 
	{
	@sub_elements = |(self!get_element_subs($s) // ()) ;
	}
else
	{
	if $.max_depth_message
		{
		@sub_elements =
				((
				'',
				'',
				Data::Dump::Tree::Type::MaxDepth.new(
					glyph => %glyphs<max_depth>,
					depth => $.max_depth,
					),
				),) ;
		}
	}

if $.keep_paths
	{
	for @sub_elements Z 0..* -> (($k, $b, $element), $index)
		{
		%.paths{$element.WHICH} = [|(%.paths{$s.WHICH}:v), [$s, $k]] ;

		@sub_elements[$index] = ($k, $b, $element, %.paths{$element.WHICH}) ;
		}
	}

@!elements_filters and $s.WHAT !=:= Mu and
	$.filter_sub_elements($s, ($current_depth, $continuation_glyph ~ %glyphs<filter>, @!renderings), @sub_elements)  ;


@sub_elements, %glyphs 
}


method filter_header(\s_replacement, $s, @rend, @ref)
{
for @.header_filters -> $filter
	{
	#$filter(s_replacement, $s, ($current_depth, $path, $glyph, @renderings), (k, b, v, f, final, want_address)) ;
	$filter(s_replacement, $s, @rend, @ref) ;
	
	CATCH 
		{
		when X::Multi::NoMatch { } #no match
		default                { .rethrow }
		}
	}
}

method filter_sub_elements($s, ($current_depth, $glyph, @renderings), @sub_elements)
{
for @.elements_filters -> $filter
	{
	$filter($s, ($current_depth, $glyph, @renderings), @sub_elements) ;
	
	CATCH 
		{
		when X::Multi::NoMatch { } #no match
		default                { .rethrow }
		}
	}
}

method filter_footer($s, ($current_depth, $glyph, @renderings))
{
for @.footer_filters -> $filter
	{
	$filter($s, ($current_depth, $glyph, @renderings)) ;
	
	CATCH 
		{
		when X::Multi::NoMatch { } #no match
		default                { .rethrow }
		}
	}
}

method get_element_header($e) 
{
(self.can('get_header')[0].candidates.grep: {.signature.params[1].type ~~ $e.WHAT}) 
	?? $.get_header($e) #specific to $e
	!! $e.^name ~~ none(self.get_P6_internal()) && $e.can('ddt_get_header') 
		?? $e.ddt_get_header() # $e class provided
		!! $.get_header($e) ;  # generic handler
}	

method !get_element_subs($s)
{
(self.can('get_elements')[0].candidates.grep: {.signature.params[1].type ~~ $s.WHAT}) 
	?? $.get_elements($s) # self is  $s specific 
	!! $s.^name ~~ none(self.get_P6_internal()) && $s.can('ddt_get_elements')
		?? $s.ddt_get_elements() # $s class provided
		!! $.get_elements($s) ;  # generic handler
}

method !split_entry(Int $current_depth, Int $width, Cool $k, Cool $b, Int $glyph_width, Cool $v, Cool $f is copy, $address)
{
my ($ddt_address, $perl_address, $link) =
	$address.defined
		?? $address.list.map: { $.superscribe_address($_) } 
		!! ('', '', '') ;

my ($kvf, @ks, @vs, @fs) ;

# handle \t
my ($k2, $v2, $f2)  = ($k // '', $v // '', $f // '').map: { .subst(/\t/, ' ' x 8, :g) } ;

if none($k2, $v2, $f2) ~~ /\n/	&& ($k2 ~ $b  ~ $v2 ~ $f2 ~ $ddt_address ~ $perl_address ~ $link).chars <= $width 
	{
	$kvf = ''
		~ $!colorizer.color($k2, $.color_kbs ?? @.kb_colors_cycle[$current_depth] !! 'key') 
		~ $!colorizer.color($b, $.color_kbs ?? @.kb_colors_cycle[$current_depth] !! 'binder') 

		~ $!colorizer.color($v2, 'value') 
		~ $!colorizer.color($.superscribe_type($f2), 'header') ~ ' ' 
		~ $!colorizer.color($ddt_address, 'ddt_address')
		~ $!colorizer.color($link, 'link') ~ ' ' 
		~ $!colorizer.color($perl_address, 'perl_address') ;
	}
else
	{
	@ks = self.split_text($k2, $width + $glyph_width) ; # $k has a bit extra space
	@ks = $!colorizer.color(@ks, $.color_kbs ?? @.kb_colors_cycle[$current_depth] !! 'key') ; 
	@ks[*-1] ~= $!colorizer.color($b, $.color_kbs ?? @.kb_colors_cycle[$current_depth] !! 'binder') if @ks ; 

	@vs = self.split_text($v2, $width) ; 
	@vs = $!colorizer.color(@vs, 'value') ; 

	@fs = self.split_text($.superscribe_type($f2), $width) ;
	@fs.append: '' unless @fs ;
	
	if (@fs.join ~ ' ' ~ $ddt_address ~ $link ~ ' ' ~ $perl_address).chars <= $width 
		{
		@fs[*-1] ~= ' ' ~ $!colorizer.color($ddt_address, 'ddt_address')
				~ $!colorizer.color($link, 'link') 
				~ ' ' ~ $!colorizer.color($perl_address, 'perl_address') ;
		}
	else
		{
		if ($ddt_address ~ $perl_address ~ ' ' ~ $link).chars <= $width
			{
			@fs.append: 
				~ $!colorizer.color($ddt_address, 'ddt_address')
				~ $!colorizer.color($link, 'link')
				~ ' ' ~ $!colorizer.color($perl_address, 'perl_address') ;
			}
		else
			{
			@fs.append: 
				~ $!colorizer.color($ddt_address, 'ddt_address')
				~ $!colorizer.color($link, 'link') ;

			@fs.append: 
				$!colorizer.color(
					$.split_text($perl_address, $width).list,
					'perl_address') ;
			}
		}

	@fs = $!colorizer.color(@fs, 'header') ;
	}

$kvf, @ks, @vs, @fs 
}

multi method split_text(Cool:U $text, $width) { '' }

multi method split_text(Cool:D $text, $width)
{
# given a, possibly empty, string, split the string on \n and width
# colorize last letter of wrapped lines

return $text if $width < 1 ;

$text.lines.flatmap:
	{
	$_.comb($width).map: 
		{	
		$_.chars == $width
			?? $_.substr(0, *-1) ~ $!colorizer.color($_.substr(*-1), 'wrap') 
			!! $_ ;
		} ;
	}
}

method superscribe($text) { $text }
method superscribe_type($text) { $text }
method superscribe_address($text) { $text }

method set_element_name($e, $name)
{
my $perl_address = $e.WHICH ;

if ! $e.defined 
	{
	$perl_address ~= ':DDT:TYPE_OBJECT' ;
	}
else
	{
	$perl_address ~= ':DDT:' ~ $e.WHICH unless $perl_address ~~ /\d ** 4/ ;
	%!element_names{$perl_address} = $name ;
	}
}

method !get_address($e)
{
my $ddt_address = $!address++ ;
my $perl_address = $e.WHICH ;

if ! $e.defined 
	{
	$perl_address ~= ':DDT:TYPE_OBJECT' ;
	}
else
	{
	$perl_address ~= ':DDT:' ~ $e.WHICH unless $perl_address ~~ /\d ** 4/ ;
	}

my ($link, $rendered) = ('', False) ;

if %!rendered{$perl_address}:exists
	{
	$rendered++ ;
	$link = ' = @' ~ %!rendered{$perl_address} ;
	$link ~= ' ' ~ %!element_names{$perl_address} if %!element_names{$perl_address}:exists
	}
else
	{
	%!rendered{$perl_address} = $ddt_address ;
	$ddt_address ~= ' ' ~ %!element_names{$perl_address} if %!element_names{$perl_address}:exists
	}

my $address = 
	$.display_address
	??	(
		'@' ~ $ddt_address,
		$.display_perl_address ?? '(' ~ $perl_address ~ ')' !! '',
		$link, 
		) 
	!!	('', '', '',) ;

$address, $rendered
}

method get_level_glyphs($level, Bool $root? = False)
{
my %glyphs = $.get_glyphs() ; 

my $glyph_width = %glyphs<empty>.chars ;
my $multi_line = %glyphs<multi_line> ;

%glyphs = $!colorizer.color(%glyphs, @!glyph_colors_cycle[$level]) ;
%glyphs<multi_line> = $!colorizer.color($multi_line, @!glyph_colors_cycle[$root ?? 0 !! $level + 1]) ;
%glyphs<__width> = $glyph_width ; #squirel in the width

%glyphs, $glyph_width	
}

method get_element_glyphs(%glyphs, Bool $is_last) # is: cached
{
# returns:
# glyph introducing the element
# glyph displayed while sub elements are added
# glyph multi line text
# glyph for multiline DDT_FINAL
# glyph to display in front of comment in filters

$is_last
	?? %glyphs<__width last     last_continuation     multi_line empty filter>
	!! %glyphs<__width not_last not_last_continuation multi_line empty filter> ;
}

method !get_class_and_parents ($a) { get_class_and_parents($a) }
sub get_class_and_parents (Any $a) is export { (($a.^name, |get_Any_parents_list($a)).map: {'.' ~ $_}).join(' ') }
 
method !get_Any_parents_list(Any $a) { get_Any_parents_list($a) }
sub get_Any_parents_list(Any $a) is export 
{
my @a = try { @a = $a.^parents.map({ $_.^name }) }  ;
$! ?? (('DDT exception', ': ', "$!"),)  !! @a ;
}

method !get_Any_attributes (Any $a)
{
my @a = try { @a = get_Any_attributes($a) }  ;
$! ?? (('DDT exception', ': ', "$!"),)  !! @a ;
}

multi sub get_Any_attributes (Any $a) is export 
{
$a.^attributes.grep({$_.^isa(Attribute)}).map:   #weeding out perl internal, thanks to moritz 
	{
	my $name = $_.name ;
	$name ~~ s~^(.).~$0.~ if $_.has_accessor ;

	my $value = $a.defined 
		?? $_.get_value($a) // 'Nil'
		!! $_.type ; 

	($name, ' = ', $value)
	}
}

method get_title()
{
my Str $t = '' ;

if $.title // False
	{
	if $.caller // False { $t = $.title ~  ' @ ' ~ callframe(3).file ~ ':' ~ callframe(3).line ~ ' ' }
	else                 { $t = $.title ~ ' ' }
	}
else
	{	
	if $.caller // False { $t = '@ ' ~ callframe(3).file ~ ':' ~ callframe(3).line ~ ' ' }
	else                 { $t = '' }
	}

$t
}


#class
}

