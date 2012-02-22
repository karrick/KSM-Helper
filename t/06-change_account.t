#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use KSM::Helper qw(:all);

########################################

sub test_change_account : Tests {
    is(KSM::Helper::change_account('foo'), 'foo');
    is(KSM::Helper::change_account('foo', ''), 'foo');
    is(KSM::Helper::change_account('foo', $ENV{LOGNAME}), 'foo');
    is(KSM::Helper::change_account('foo', 'root'), 'sudo -n foo');
    is(KSM::Helper::change_account('foo', 'other'), 'sudo -inu other foo');
}
