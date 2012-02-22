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

sub test_shell_quote_no_subst : Tests {
    is(shell_quote('foo'), 'foo');
    is(shell_quote('--bar'), '--bar');
    is(shell_quote('a_0/Z.-9'), 'a_0/Z.-9');
}

sub test_shell_quote_undef : Tests {
    is(shell_quote(), '');
}

sub test_shell_quote_empty_string : Tests {
    is(shell_quote(''), "''");
}

sub test_shell_quote_special_character : Tests {
    is(shell_quote('!@#$%^&*(),<>?'), '\!\@\#\$\%\^\&\*\(\)\,\<\>\?');
}
