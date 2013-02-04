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

sub test_should_strip_whitespace_from_string : Tests {
    is(strip(), undef);
    is(strip(""), "");
    is(strip("   foo"), "foo");
    is(strip("foo   "), "foo");
    is(strip("   foo   "), "foo");
}
