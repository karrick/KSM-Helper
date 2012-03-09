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

sub test_no_subst : Tests {
    is(KSM::Helper::shell_quote('foo'), 'foo');
    is(KSM::Helper::shell_quote('--bar'), '--bar');
    is(KSM::Helper::shell_quote('a_0/Z.-9'), 'a_0/Z.-9');
}

sub test_undef : Tests {
    is(KSM::Helper::shell_quote(), '');
}

sub test_empty_string : Tests {
    is(KSM::Helper::shell_quote(''), "''");
}

sub test_special_character : Tests {
    is(KSM::Helper::shell_quote('!@#$%^&*(),<>?'), '\!\@\#\$\%\^\&\*\(\)\,\<\>\?');
}

sub test_command : Tests {
    is(KSM::Helper::shell_quote('emacs --daemon'), 'emacs\ --daemon');
}
