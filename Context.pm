package Text::Context;
use Text::Context::EitherSide;

use constant MAX_CONTEXT_LENGTH           => 70;
use constant WORDS_EITHER_SIDE            => 5;
use constant DEFAULT_HTML_HIGHLIGHT_START => '<span class="quoted">';
use constant DEFAULT_HTML_HIGHLIGHT_END   => '</span class="quoted">';

use HTML::Entities;

our $VERSION = "2.0";

=head1 NAME

Text::Context - Handle highlighting search result context snippets

=head1 SYNOPSIS

  use Text::Context;

  my $snippet = Text::Context->new($text, @keywords);

  $snippet->keywords("foo", "bar"); # In case you change your mind

  $snippet->offsets() # Array containing context string and offsets of terms

  print $snippet->as_html;

=head1 DESCRIPTION

Given a piece of text and some search terms, produces an object
which locates the search terms in the message, extracts a reasonable-length
string containing all the search terms, and optionally dumps the string out
as HTML text with the search terms highlighted in bold.

=cut

use strict;

=head2 new

Creates a new snippet object for holding and formatting context for
search terms.

=cut

sub new {
	my ($self, $text, @keywords) = @_;
	bless {
		text     => $text,
        keywords => [map lc,@keywords]
	}, $self;
}

=head2 keywords

Accessor method to get/set keywords. As the context search is done
case-insensitively, the keywords will be lower-cased.

=cut

sub keywords {
	my $self = shift;
	if (@_) {
		delete $self->{offsets};    # Uncache
        delete $self->{snippet};
		$self->{keywords} = [map lc, @_];
	}
	@{ $self->{keywords} };
}

=head2 as_text

Calculates a "representative" string which contains
the given search terms. If there's lots and lots of context between the
terms, it's replaced with an ellipsis.

=cut

sub as_text {
    my $self = shift;
    return $self->{snippet} if exists $self->{snippet};

	my @msg = split /\n/, $self->{text};

	my ($sparse, $in_order) = _locate_keywords(\@msg, $self->keywords);

	return undef unless @$in_order;    # Didn't find any keywords at all.

    $self->{in_order} = $in_order;
	return $self->{snippet} = _present($sparse, @$in_order);
}


=head2 offsets

Calculate and return an array of the offsets to start and end highlighting
of the string returned by C<as_text>; the return value will be of the form:

    [
        [ "foo", $foo_start, $foo_end ]
        [ "bar", $bar_start, $bar_end ]
    ] 

Note: Previous versions of C<Text::Context> lumped C<as_text> and
C<offsets> into one data structure. Hence, code which uses old versions
will need to be updated.

=cut

sub offsets {
	my $self = shift;

	# Have we done this before?
	return $self->{offsets} if exists $self->{offsets};
	return undef unless $self->keywords;
    
    my $context = $self->as_text;
    return undef unless $context;

	return $self->{offsets} = _make_offsets($context, @{$self->{in_order}});
}

sub _locate_keywords {

	# Find all the keywords, if we can, creating a sparse array of
	# output, and putting the keywords in the order they appear.
	#
	# Returns an array reference containing the relevant lines in the
	# message, followed by an array reference of the keywords in-order.

	my @msg = @{ shift @_ };
	my %to_find = map { $_ => 1 } @_;
	my @in_order;
	my @text;

	for my $line_no (0 .. $#msg) {
		last unless keys %to_find;    # If there's nothing left, we're done.

		my $line = $msg[$line_no];
		chomp $line;
        my $lline = lc $line;

		for my $word (keys %to_find) {
			if ($lline =~ /\b\Q$word\E\b/) { 
				if ($text[$line_no]) {

					# We have already found one word on this line.
					push @{ $text[$line_no] }, $word;
				} else {
					$text[$line_no] = [ $line, $word ];
				}
				push @in_order, $word;
				delete $to_find{$word};
			}
		}
	}

	return (\@text, \@in_order);
}

sub _present {

	# Turn the sparse array into a presentable string. 
	# Collapses multiple non-contextual lines into a single ellipsis.

	my @text     = @{ shift @_ };
	my @keywords = @_;
	my $present;
	while (@text) {
		my $elem = shift @text;
		my $line = defined $elem ? $elem->[0] : "...";
		if (length $line > MAX_CONTEXT_LENGTH) {
			my @words = @{$elem}[ 1 .. $#$elem ];
			$line = _shorten($line, @words);
		}

		$present .= $line;

		if ($present =~ /\.\.\.$/) {
			shift @text while @text and not defined $text[0];
		}
		$present .= " ";
	}

	chop $present;
	return $present;
}

sub _shorten {

	# Try a variety of means to get the string down to a sensible size.
	my ($line, @words) = @_;

	# First, let's see if we can slim it down by *just* trying to find
	# the words (with maybe one word either side)
	my $pat = join '\b.+?\b', map quotemeta, @words;
	$line =~ /((\b\w+\b)?.*?$pat.*?(\b\w+\b)?)/smi;
	return $1 if $1 and length $1 < MAX_CONTEXT_LENGTH;

	# So there's too much stuff *between* the words; so get a per-word context
	for my $n (WORDS_EITHER_SIDE .. 2) {
		my $try = Text::Context::EitherSide::get_context($n, $line, @words);
		return $try if length $try < MAX_CONTEXT_LENGTH;
	}

	# This ordinarily can't happen but at least provide *something*.
	return join " ... ", @words;

}

sub _make_offsets {

	# Takes the finalized context string and a list of keywords in
	# order, and locates the keywords in the string again, picking out
	# the offsets.

	my $string   = shift;
	my @in_order = @_;
	my @ret;

	# Now calculate the offsets.
	for (@in_order) {
        $string =~ /\b\Q$_\E\b/i;
        my $pos = length $`;
		push @ret, [ $_, $pos, $pos+length];
	}

    # But wait - they're not quite in order, because if the same 
    # line contains two search terms, the one given first will win.

	return [sort { $a->[1] <=> $b->[1] } @ret ];
}

=head2 as_html([ start => "<some tag>", end => "<some end tag>" ])

Markup the snippet as a HTML string using the specified delimiters or
with a default set of delimiters (C<E<lt>span class="quoted"E<gt>>).

=cut

sub as_html {
	my $self = shift;
	my %args = @_;

	my ($start, $end) = @args{qw(start end)};
	$start = defined $start ? $start : DEFAULT_HTML_HIGHLIGHT_START;
	$end   = defined $end   ? $end   : DEFAULT_HTML_HIGHLIGHT_END;

	my $offset_r = $self->offsets();
	return unless $offset_r;

	my @offsets = @$offset_r;       # Use a copy so we don't modify orig.
	my $string  = $self->as_text();
    return unless $string;

	my $pos = 0;
	my $out;
	for (@offsets) {
		$out .= encode_entities(substr($string, $pos, $_->[1] - $pos));
        # Case may differ, so we can't use the original keyword.
        $out .= $start;
        $out .= encode_entities(substr($string, $_->[1], length $_->[0]));
        $out .= $end;
		$pos = $_->[2];
	}
	$out .= encode_entities(substr($string, $pos));
	return $out;
}

=head1 COPYRIGHT

  Copyright (C) 2002 Kasei Limited

You may use and redistribute this module under the terms of the Artistic
License.

=cut

1;
