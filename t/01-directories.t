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

sub test_ensure_directory_exists_croaks_if_cannot_create : Tests {
    eval {ensure_directory_exists("/root/foo/bar")};
    like($@, qr/Permission/);
}

sub test_ensure_directory_exists_returns_same_name : Tests {
    is(ensure_directory_exists("t/data/bozo"),
       "t/data/bozo");
}

sub test_ensure_directory_exists_creates_directories : Tests {
    system("rm -rf t/data");
    ok(ensure_directory_exists("t/data/foo/bar/baz"));
    ok(-d "t/data/foo/bar/baz");
}

########################################

sub test_create_required_parent_directories_croaks_if_cannot_create : Tests {
    eval {create_required_parent_directories("/root/foo/bar")};
    like($@, qr/Permission/);
}

sub test_create_required_parent_directories_returns_same_name : Tests {
    is(create_required_parent_directories("t/data/foo.txt"),
       "t/data/foo.txt");
}

sub test_create_required_parent_directories_creates_directories : Tests {
    system("rm -rf t/data");
    ok(create_required_parent_directories("t/data/foo/bar/baz.txt"));
    ok(-d "t/data/foo/bar");
}
