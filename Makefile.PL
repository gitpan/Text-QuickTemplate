use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Text::QuickTemplate',
    'VERSION_FROM'	=> 'QuickTemplate.pm', # finds $VERSION
    'PREREQ_PM'		=> { # module_name    => version
                            Readonly          => '1.00',
                            Exception::Class  => '1.20',
                           },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'QuickTemplate.pm', # retrieve abstract from module
       AUTHOR     => 'Eric Roode <roode@cpan.org>') : ()),
);
