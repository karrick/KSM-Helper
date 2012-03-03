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
    is_deeply(KSM::Helper::change_account(['foo']), ['foo']);
    is_deeply(KSM::Helper::change_account(['foo'], ''), ['foo'],
	      "when account empty string");
    is_deeply(KSM::Helper::change_account(['foo'], $ENV{LOGNAME}), ['foo'],
	      "when account LOGNAME");
    is_deeply(KSM::Helper::change_account(['foo'], 'root'), ['sudo','-n','foo'],
	      "when account root");
    is_deeply(KSM::Helper::change_account(['foo'], 'other'), ['sudo','-inu','other','foo'],
	      "when other");
    # TODO: WHAT HAPPENS IF LOGNAME *IS* ROOT AND SUDO? I THINK CODE
    # IS CORRECT, BUT NEED TO TEST
}
