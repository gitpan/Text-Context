#!/usr/bin/perl 
use Text::Context;
use Test::More tests => 2;
use strict;

#make sure that we can set the max_len for as_text and as_html
my $test_str = "this is a test string.\n\nThe which we are using to test this module\n\nSo that the tests work\n\n";
my $len = 30;
my $s = Text::Context->new($test_str, 'test');

my $text = $s->as_text(max_len => $len);
ok(length($text) < $len , "as_text max_len works");

$text = $s->as_html(start => '<>', end => '<>', max_len => $len);
$text =~ s/( ?\.\.\. ?|<>)//g;
ok(length($text) < $len, "as_html max_len works");
