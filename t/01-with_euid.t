#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Carp;
use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use KSM::Helper qw(:all);

########################################

sub test_with_euid_returns_result : Tests {
    my $euid = $>;
    my $result = with_euid($euid,
			   sub {
			       42;
			   });
    is($result, 42);
}

sub test_with_euid_changes_euid : Tests {
    my $euid = $>;

    # NOTE: wrap test in eval because test user may not be able to do this
    eval {
    };

    my $result = with_euid($euid,
			   sub {
			       42;
			   });
    is($result, 42);
}
