#!/usr/bin/env perl

use utf8;
use diagnostics;
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
    is_deeply(KSM::Helper::wrap_sudo(['foo']), ['foo']);
    is_deeply(KSM::Helper::wrap_sudo(['foo'], ''), ['foo'],
	      "when account empty string");
    is_deeply(KSM::Helper::wrap_sudo(['foo'], $ENV{LOGNAME}), ['foo'],
	      "when account LOGNAME");
    is_deeply(KSM::Helper::wrap_sudo(['foo'], 'root'), ['sudo','-n','foo'],
	      "when account root");
    is_deeply(KSM::Helper::wrap_sudo(['foo'], 'other'), ['sudo','-inu','other','foo'],
	      "when other");
    # TODO: WHAT HAPPENS IF LOGNAME *IS* ROOT AND SUDO? I THINK CODE
    # IS CORRECT, BUT NEED TO TEST.  I'M DECIDED TO ASSUME MODULE
    # TESTS ARE *NOT* EXECUTED BY 'root' ACCOUNT, AS THIS WOULD BE
    # POOR PRACTICE.
}
