use strict;
use warnings;

use Test::More tests => 17;
use Text::Context;

undef $/; my $text = <DATA>;

{
my $snippet = Text::Context->new($text);
isa_ok($snippet, "Text::Context");

$snippet->keywords(qw(Wadler XQuery));
is(join (" ", $snippet->keywords), "Wadler XQuery", "Keywords can be set");
}

{
my $snippet = Text::Context->new($text, "Wadler", "XQuery");
isa_ok($snippet, "Text::Context");
is(
    join (" ", $snippet->keywords),
    "Wadler XQuery",
    "Keywords can be set in constructor and retrieved"
);
}

{
my $snippet = Text::Context->new($text, "Wadler", "XQuery");

my $expected = [
    "... I\'m just quoting Phil Wadler, who recently (at the"
        . " School of Advanced FP in Oxford, England, August) in his "
        . "lecture about XQuery said that",
    [ 'wadler', 26,  32 ],
    [ 'xquery', 126, 132 ]
];

is_deeply($snippet->offsets, $expected,
    "Simple context string with located offsets");
is_deeply($snippet->offsets, $expected, "Offset caching works");

$snippet = Text::Context->new($text, "XQuery", "Wadler");
is_deeply($snippet->offsets, $expected,
    "Order of keywords is not significant");
}

{
my $snippet = Text::Context->new($text);
is($snippet->offsets, undef, "We get no offsets with no keywords");

$snippet->keywords("Wadler", "XQuery");
isnt($snippet->offsets, undef, "Changing keywords uncaches offsets");

$snippet->keywords("Wadler", "Foobar");
my $expected = [
    "... I'm just quoting Phil Wadler, who recently (at the School of Advanced",
    [ 'wadler', 26, 32 ]
];
is_deeply($snippet->offsets, $expected,
    "Sensible results with one not-found keyword");

$snippet->keywords("Foobar", "Wadler");
is_deeply($snippet->offsets, $expected, "And order is still not important");

$snippet->keywords("Foobar", "Bazquux");
is($snippet->offsets, undef,
    "But still no offsets with zero keywords found");

}

{
my $snippet = Text::Context->new($text, "Wadler", "XQuery");

my $expected =
    "... I'm just quoting Phil <B>Wadler</B>, who recently (at the "
    . "School of Advanced FP in Oxford, England, August) in his lecture "
    . "about <B>XQuery</B> said that";

is($snippet->as_html(start => "<B>", end => "</B>"),
    $expected, "as_html can take custom delimiters");

is($snippet->as_html(start => "<B>", end => "</B>"),
    $expected, "We don't modify the offsets data structure (any more)");

$expected =~ s/B>/span class="quoted">/g;

is($snippet->as_html(), $expected,
    "as_html uses span as default delimiters");
}

{
my $snippet = Text::Context->new($text, "functional language");

my $expected = [
    '... > >While XSLT is considered to be a functional language by experts in',
    [ 'functional language', 40, 59 ]
];

is_deeply($snippet->offsets, $expected, "A phrase works");
$snippet->keywords("functional", "language");
$expected = [
    '... > >While XSLT is considered to be a functional language by experts in',
    [ 'functional', 40, 50 ],
    [ 'language',   51, 59 ],
];
is_deeply($snippet->offsets, $expected,
    "A multiply-occurring set of keywords finds the first match");
}

1;

__DATA__

--- bryan wrote:
> 
> >While XSLT is considered to be a functional language by experts in
> this 
> >field, it is definitely not a very nice representative of this class
> of 
> >programming languages. 
> 
> OOOOH that's a baaad thing you said. :) 

I'm just quoting Phil Wadler, who recently (at the School of Advanced
FP in Oxford, England, August) in his lecture about XQuery said that
"XSLT is probably the most used functional language and the ugliest
one".


> 
> Anyway, it seems to me that you prefer Haskell out of the various
> functional languages, do you have a particular reason for this? I
> have
> problems with Haskell, I've tried and I've tried but it's frankly
> quite
> hard for me to follow programs written in Haskell once they get
> beyond
> a
> couple pages when printed, for functional languages I prefer Lisp and
> Erlang. Especially Erlang. 
> 
> So anyway what do you like especially about Haskell? 


Strong typing, polymorphic types, type classes

Higher order functions

Huge expressiveness

Lazy evaluation + pattern matching

The (built-in support for the) very precise (monadic) approach to
encapsulating operations with side effects.


They even joke that once you have specified the types correctly, then
the solution just starts working... :o)  and in reality quite often
this is really the case.

But I'm not comparing Haskell to other languages, just saying that I
like it.



=====
Cheers,

Dimitre Novatchev.
http://fxsl.sourceforge.net/ -- the home of FXSL

__________________________________________________
Do you Yahoo!?
Faith Hill - Exclusive Performances, Videos & More
http://faith.yahoo.com

 XSL-List info and archive:  http://www.mulberrytech.com/xsl/xsl-list
