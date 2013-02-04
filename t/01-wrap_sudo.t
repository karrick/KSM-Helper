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

sub test_wrap_sudo : Tests {
    is_deeply(wrap_sudo([]), []);
    is_deeply(wrap_sudo(['foo']), ['foo']);
    is_deeply(wrap_sudo(['foo'], 'user1'), ['sudo','-Hnu','user1','foo']);
}
