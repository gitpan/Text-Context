# Fixes in version 1.1.

use Text::Context;
use Test::More tests => 2; 

my $data = <<EOF;

> > Is it possible to add a function like this at runtime or should I just
> > bite the bullet and write a plugin ?

>

> There is no bullet to bite when writing plugins.

EOF

my $snippet = Text::Context->new($data, "bite", "bullet");

$expected =
'... &gt; &gt; <span class="quoted">bite</span class="quoted"> the'.
' <span class="quoted">bullet</span class="quoted"> and write a plugin ?';

is($snippet->as_html, $expected, "ordering is no longer important. Good.");

$snippet->keywords("BITE", "Bullet");
is($snippet->as_html, $expected, "case is no longer important. Good.");
