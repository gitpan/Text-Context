use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
warn "The 2.0 release of this module contains incompatible API changes!
Please read the documentation for the as_text method!\n";
WriteMakefile(
    'NAME'		=> 'Text::Context',
    'VERSION_FROM'	=> 'Context.pm', # finds $VERSION
    'PREREQ_PM'		=> { Text::Context::EitherSide => 1 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Context.pm', # retrieve abstract from module
       AUTHOR     => 'Simon Cozens <simon@kasei.com>') : ()),
);
