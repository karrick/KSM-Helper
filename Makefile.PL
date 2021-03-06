use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'KSM::Helper',
    AUTHOR              => q{Karrick S. McDermott <karrick@karrick.net>},
    VERSION_FROM        => 'lib/KSM/Helper.pm',
    ABSTRACT_FROM       => 'lib/KSM/Helper.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    BUILD_REQUIRES => {
	'Capture::Tiny' => 0.17,
	'Test::Class' => 0.35,
        'Test::More' => 0,
    },
    PREREQ_PM => {
	'KSM::Logger' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'KSM-Helper-*' },
);

sub MY::postamble {
    my $postamble = <<'MAKE_FRAG';
.PHONY: rpm

rpm:	distcheck dist
	cpan2rpm --force --no-sign $(DISTVNAME).tar.$(SUFFIX)
MAKE_FRAG

    return $postamble;
}
