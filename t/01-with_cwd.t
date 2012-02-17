#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use POSIX ();
use KSM::Helper qw(:all);

########################################

sub test_with_cwd_returns_to_previous_directory_even_when_die : Tests {
    my $original_directory = POSIX::getcwd();

    eval {
	with_cwd('empty', sub { die('death & dieing') });
    };
    like($@, qr/^death & dieing/);
    is(POSIX::getcwd(), $original_directory);
}
