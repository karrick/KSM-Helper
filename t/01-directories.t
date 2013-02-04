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

sub tempdir_wrapper_for_mac {
    my $start = POSIX::getcwd();
    chdir(File::Temp::tempdir()) or fail($!);
    my $temp = POSIX::getcwd();
    chdir($start) or fail($!);
    $temp;
}

sub create_test_data_directory : Test(setup) {
    my ($self) = @_;
    $self->{start_directory} = POSIX::getcwd();
    $self->{dir} = tempdir_wrapper_for_mac();
}

sub remove_test_artifact_and_return_to_start_directory : Test(teardown) {
    my ($self) = @_;
    chdir($self->{start_directory}) or fail($!);
    File::Path::rmtree($self->{dir}) if -d $self->{dir};
}

########################################

sub test_ensure_directory_exists_dies_if_cannot_create : Tests {
    eval {ensure_directory_exists("/root/foo/bar")};
    like($@, qr/Permission/);
}

sub test_ensure_directory_exists_returns_same_name : Tests {
    my ($self) = @_;
    my $dir = sprintf("%s/foo", $self->{dir});
    is(ensure_directory_exists($dir), $dir);
}

sub test_ensure_directory_exists_creates_directories : Tests {
    my ($self) = @_;
    my $dir = sprintf("%s/foo/bar/baz", $self->{dir});
    ok(ensure_directory_exists($dir));
    ok(-d $dir);
}

########################################

sub test_create_required_parent_directories_dies_if_cannot_create : Tests {
    eval {create_required_parent_directories("/root/foo/bar")};
    like($@, qr/Permission/);
}

sub test_create_required_parent_directories_returns_same_name : Tests {
    my ($self) = @_;
    my $file = sprintf("%s/foo/bar.baz", $self->{dir});
    is(create_required_parent_directories($file), $file);
}

sub test_create_required_parent_directories_creates_directories : Tests {
    my ($self) = @_;
    my $file = sprintf("%s/foo/bar.baz", $self->{dir});
    ok(create_required_parent_directories($file));
    ok(-d sprintf("%s/foo", $self->{dir}));
}
