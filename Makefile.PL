use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Text::Context',
    'VERSION_FROM'	=> 'Context.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        Text::Context::EitherSide => 1.1
    }, # e.g., Module::Name => 1.1
);
