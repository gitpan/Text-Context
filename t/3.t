# Fixes in version 1.2.

use Text::Context;
use Test::More tests => 1; 

my $data = <<EOF;

> > Is it possible to add a function like this at runtime or should I just
> > bite the bullet and write a plugin ?

>

> There is no bullet to bite when writing plugins.

EOF

my $snippet = Text::Context->new($data, "func")->as_html;
like($snippet, qr/^$/);
