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

sub test_file_contents_croaks_when_missing_file : Tests {
    eval { file_contents("t/data/does-not-exist") };
    like($@, qr/cannot open file/);
    like($@, qr/\n$/);
}

sub test_file_contents_read_grabs_entire_file_in_single_call : Tests {
    my ($self) = @_;

    $self->{filename} = "t/data/test.txt";
    ensure_directories_exist($self->{filename});

    open(FH, '>', $self->{filename}) or fail sprintf("cannot open file for writting: %s", $!);
    for(my $index = 1; $index < 6; $index++) {
	print FH sprintf("Number %d\n", $index);
    }
    close(FH) or fail sprintf("cannot close file: %s", $!);

    is(file_contents($self->{filename}),
       "Number 1\nNumber 2\nNumber 3\nNumber 4\nNumber 5\n");
}

########################################

sub test_file_read_error_ends_in_newline : Tests {
    eval { file_read("t/data/does-not-exist") };
    like($@, qr/\n$/);
}

sub test_file_read_returns_contents_of_blob : Tests {
    my $blob = file_read("t/fixtures/hello.txt");
    like($blob, qr|日本語|);
    like($blob, qr|שלום|);
}

sub test_file_write_actually_writes_utf_8_stuff : Tests {
    my ($self) = @_;
    my $blob = "La Cité interdite présente des chefs-d'oeuvre qu'elle va prêter au Louvre";
    file_write("t/data/utf8.txt", $blob);
    is(file_read("t/data/utf8.txt"), $blob);
}

sub test_file_write_returns_contents_of_blob : Tests {
    my ($self) = @_;
    my $blob = "La Cité interdite présente des chefs-d'oeuvre qu'elle va prêter au Louvre";
    my $written = file_write("t/data/utf8.txt", $blob);
    is($written, $blob);
}
