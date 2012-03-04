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

sub cleanup_before_each_test : Tests(setup) {
    system("rm -rf t/data");
}

sub cleanup_after_all_tests : Tests(shutdown) {
    system("rm -rf t/data");
}

########################################

sub test_ensure_directories_exist_croaks_if_cannot_create : Tests {
    eval {ensure_directories_exist("/root/foo/bar")};
    like($@, qr/Permission/);
}

sub test_ensure_directories_exist_returns_same_name : Tests {
    is(ensure_directories_exist("t/data/foo.txt"),
       "t/data/foo.txt");
}

sub test_ensure_directories_exist_creates_directories : Tests {
    system("rm -rf t/data");
    ok(ensure_directories_exist("t/data/foo/bar/baz.txt"));
    ok(-d "t/data/foo/bar");
}
