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
# all

sub test_all_croaks_when_no_list : Tests {
    eval { KSM::Helper::all(undef, sub { shift eq shift }) };
    like($@, qr|ought to be array reference|, "when list undef");

    eval { KSM::Helper::all('money', sub { shift eq shift }) };
    like($@, qr|ought to be array reference|, "when list not ref to array");
}

sub test_all_croaks_when_no_function : Tests {
    eval { KSM::Helper::all([]) };
    like($@, qr/\bfunction\b/, "when function undef");

    eval { KSM::Helper::all(['money'], 'money') };
    like($@, qr/\bfunction\b/, "when function not sub");
}

sub test_all_checks_each_element : Tests {
    is(all([2, 4, 6], sub { my ($item) = @_; ($item % 2 == 0 ? 1 : 0) }), 1);
    is(all([1, 4, 6], sub { my ($item) = @_; ($item % 2 == 0 ? 1 : 0) }), 0);
    is(all([2, 5, 6], sub { my ($item) = @_; ($item % 2 == 0 ? 1 : 0) }), 0);
    is(all([2, 4, 7], sub { my ($item) = @_; ($item % 2 == 0 ? 1 : 0) }), 0);
}

########################################
# any

sub test_any_croaks_when_no_list : Tests {
    eval { KSM::Helper::any(undef, sub { shift eq shift }) };
    like($@, qr|ought to be array reference|, "when list undef");

    eval { KSM::Helper::any('money', sub { shift eq shift }) };
    like($@, qr|ought to be array reference|, "when list not ref to array");
}

sub test_any_croaks_when_no_function : Tests {
    eval { KSM::Helper::any([]) };
    like($@, qr|ought to be function|, "when function undef");

    eval { KSM::Helper::any(['money'], 'money') };
    like($@, qr|ought to be function|, "when function not sub");
}

sub test_any_checks_each_element : Tests {
    is(any([2, 4, 6], sub { my ($item) = @_; ($item % 2 == 0 ? 1 : 0) }), 1);
    is(any([1, 4, 6], sub { my ($item) = @_; ($item % 2 == 0 ? 1 : 0) }), 1);
    is(any([2, 5, 6], sub { my ($item) = @_; ($item % 2 == 0 ? 1 : 0) }), 1);
    is(any([2, 4, 7], sub { my ($item) = @_; ($item % 2 == 0 ? 1 : 0) }), 1);
    is(any([1, 3, 5], sub { my ($item) = @_; ($item % 2 == 0 ? 1 : 0) }), 0);
}
