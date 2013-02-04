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
# file_contents

sub test_file_contents_dies_when_missing_file : Tests {
    my ($self) = @_;
    my $file = sprintf("%s/does-not-exist", $self->{dir});
    eval { file_contents($file) };
    like($@, qr/cannot open file/);
    like($@, qr/\n$/, "error message ought terminate in newline");
}

sub test_file_contents_returns_contents_of_blob : Tests {
    my $blob = file_contents("t/fixtures/hello.txt");
    like($blob, qr|日本語|);
    like($blob, qr|שלום|);
}

########################################
# file_read

sub test_file_read_dies_when_missing_file : Tests {
    my ($self) = @_;
    my $file = sprintf("%s/does-not-exist", $self->{dir});
    eval { file_contents($file) };
    like($@, qr/cannot open file/);
    like($@, qr/\n$/, "error message ought terminate in newline");
}

sub test_file_read_returns_contents_of_blob : Tests {
    my $blob = file_read("t/fixtures/hello.txt");
    like($blob, qr|日本語|);
    like($blob, qr|שלום|);
}

########################################
# file_write

sub test_file_write_returns_contents_of_blob : Tests {
    my ($self) = @_;
    my $file = sprintf("%s/utf8.txt", $self->{dir});
    my $blob = "La Cité interdite présente des chefs-d'oeuvre qu'elle va prêter au Louvre";
    my $written = file_write($file, $blob);
    is($written, $blob);
}

sub test_file_write_actually_writes_utf_8_stuff : Tests {
    my ($self) = @_;
    my $file = sprintf("%s/utf8.txt", $self->{dir});
    my $blob = "La Cité interdite présente des chefs-d'oeuvre qu'elle va prêter au Louvre";
    file_write($file, $blob);
    is(file_read($file), $blob);
}
