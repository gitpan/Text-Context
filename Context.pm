package Text::Context;
use strict;
use warnings;

our $VERSION = "3.3";

=head1 NAME

Text::Context - Handle highlighting search result context snippets

=head1 SYNOPSIS

  use Text::Context;

  my $snippet = Text::Context->new($text, @keywords);

  $snippet->keywords("foo", "bar"); # In case you change your mind

  print $snippet->as_html;
  print $snippet->as_text;

=head1 DESCRIPTION

Given a piece of text and some search terms, produces an object
which locates the search terms in the message, extracts a reasonable-length
string containing all the search terms, and optionally dumps the string out
as HTML text with the search terms highlighted in bold.

=head2 new

Creates a new snippet object for holding and formatting context for
search terms.

=cut

sub new {
    my ($class, $text, @keywords) = @_;
    my $self = bless { text => $text, keywords => [] }, $class;
    $self->keywords(@keywords);
    return $self;
}

=head2 keywords

Accessor method to get/set keywords. As the context search is done
case-insensitively, the keywords will be lower-cased.

=cut

sub keywords {
    my ($self, @keywords) = @_;
    $self->{keywords} = [ map {s/\s+/ /g; lc $_} @keywords ] if @keywords;
    return @{$self->{keywords}};
}

=begin maintainance

=head2 prepare_text

Turns the text into a set of Text::Context::Para objects, collapsing
multiple spaces in the text and feeding the paragraphs, in order, onto
the C<text_a> member.

=end

=cut

sub para_class {"Text::Context::Para"}
sub prepare_text {
    my $self = shift;
    my @paras = split /\n\n/, $self->{text};
    for (0..$#paras) {
        my $x = $paras[$_];
        $x =~ s/\s+/ /g;
        push @{$self->{text_a}}, $self->para_class->new($x, $_);
    }
}

=begin maintainance

This is very clever. To determine which keywords "apply" to a given
paragraph, we first produce a set of all possible keyword sets. For
instance, given "a", "b" and "c", we want to produce

    a b c
    a b 
    a   c
    a
      b c
      b
        c

We do this by counting in binary, and then mapping the counts onto
keywords.

=end

=cut

sub permute_keywords {
    my $self = shift;
    my @permutation;
    for my $bitstring (1..(2**@{$self->{keywords}})-1) {
        my @thisperm;
        for my $bitmask (0..@{$self->{keywords}}-1) {
            push @thisperm, $self->{keywords}[$bitmask] 
                if $bitstring & 2**$bitmask;
        }
        push @permutation, \@thisperm;
    }
    return reverse @permutation;
}

=for maintainance

Now we want to find a "score" for this paragraph, finding the best set
of keywords which "apply" to it. We favour keyword sets which have a
large number of matches (obviously a paragraph is better if it matches
"a" and "c" than if it just matches "a") and with multi-word keywords.
(A paragraph which matches "fresh cheese sandwiches" en bloc is worth
picking out, even if it has no other matches.)

=cut

sub score_para {
    my ($self, $para) = @_;
    my $content = $para->{content};
    my %matches;
    # Do all the matching of keywords in advance of the boring
    # permutation bit
    for my $word (@{$self->{keywords}}) {
        my $word_score = 0;
        $word_score += 1 + ($content =~ tr/ / /) if $content =~ /\b\Q$word\E\b/i;
        $matches{$word} = $word_score;
    }
    #XXX : Possible optimization: Give up if there are no matches
    
    for my $wordset ($self->permute_keywords) { 
        my $this_score = 0;
        $this_score += $matches{$_} for @$wordset;
        $para->{scoretable}[$this_score] = $wordset if $this_score > @$wordset;
    }
    $para->{final_score} = $#{$para->{scoretable}};
}

sub _set_intersection {
    my %union; my %isect;
    for (@_) { $union{$_}++ && ($isect{$_}=$_) }
    return values %isect;
}

sub _set_difference {
    my ($a, $b) = @_;
    my %seen; @seen{@$b} = ();
    return grep { !exists $seen{$_} } @$a;
}

sub get_appropriate_paras {
    my $self = shift;
    my @app_paras;
    my @keywords = @{$self->{keywords}};
    my @paras = sort { $b->{final_score} <=> $a->{final_score} }
                     @{$self->{text_a}};
    for my $para (@paras) {
        my @words = _set_intersection($para->best_keywords, @keywords);
        if (@words) {
            @keywords = _set_difference(\@keywords, \@words);
            $para->{marked_words} = \@words;
            push @app_paras, $para;
            last if !@keywords;
        }
    }
    $self->{app_paras} = [sort {$a->{order} <=> $b->{order}} @app_paras];
    return @{$self->{app_paras}};
}

=head2 paras

    @paras = $self->paras($maxlen)

Return shortened paragraphs to fit together into a snippet of at most
C<$maxlen> characters.

=cut

sub paras {
    my $self = shift;
    my $max_len = shift || 80;
    $self->prepare_text;
    $self->score_para($_) for @{$self->{text_a}};
    my @paras = $self->get_appropriate_paras;
    return unless @paras;
    # XXX: Algorithm may get better here by considering number of marked
    # up words as weight
    return map {$_->slim($max_len/@paras)} $self->get_appropriate_paras;
}

=head2 as_text

Calculates a "representative" string which contains
the given search terms. If there's lots and lots of context between the
terms, it's replaced with an ellipsis.

=cut

sub as_text { return join " ... ", map {$_->as_text} $_[0]->paras; }

=head2 as_html([ start => "<some tag>", end => "<some end tag>" ])

Markup the snippet as a HTML string using the specified delimiters or
with a default set of delimiters (C<E<lt>span class="quoted"E<gt>>).

=cut

sub as_html {
    my $self = shift;
    my %args = @_;

    my ($start, $end) = @args{qw(start end)};
    return join " ... ", map {$_->marked_up($start, $end)} $self->paras;
}

package Text::Context::Para;
use HTML::Entities;
use constant DEFAULT_START_TAG => '<span class="quoted">';
use constant DEFAULT_END_TAG   => "</span>";
use Text::Context::EitherSide qw(get_context);

sub new {
    my ($class, $content, $order) = @_;
    return bless {
        content      => $content,
        scoretable   => [],
        marked_words => [],
        final_score  => 0,
        order        => $order
    }, $class
}

sub best_keywords { 
    my $self = shift;
    return @{$self->{scoretable}->[-1] || []};
}

sub slim {
    my ($self, $max_weight) = @_;
    $self->{content}=~s/^\s+//; $self->{content}=~s/\s+$//;
    return $self if length $self->{content} <= $max_weight;
    my @words = split /\s+/, $self->{content};
    for(reverse(0..@words/2)) {
        my $trial = get_context($_, $self->{content}, @{$self->{marked_words}});
        if (length $trial < $max_weight) {
            $self->{content} = $trial;
            return $self;
        }
    }
    $self->{content} = join " ... ", @{$self->{marked_words}};
    return $self; # Should not happen.
}

sub as_text { return $_[0]->{content} }
sub marked_up { 
    my $self      = shift;
    my $start_tag = shift || DEFAULT_START_TAG;
    my $end_tag   = shift || DEFAULT_END_TAG;
    my $content   = $self->as_text;
    # Need to escape entities in here.
    my $re = join "|", map { qr/\Q$_\E/i } @{$self->{marked_words}};
    my $re2 = qr/\b($re)\b/i;
    my @fragments = split /$re2/i, $content;
    my $output;
    for my $orig_frag (@fragments) {
        my $frag = encode_entities($orig_frag);
        if ($orig_frag =~ /$re2/i) {
            $frag = $start_tag.$frag.$end_tag;
        }
        $output .= $frag;
    }
    return $output;
}

=head1 COPYRIGHT

  Copyright (C) 2002 Kasei Limited

You may use and redistribute this module under the terms of the Artistic
License.

=cut

1;
