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
    like($@, qr/unable to open file/);
}

sub test_file_contents_read_grabs_entire_file_in_single_call : Tests {
    my ($self) = @_;

    $self->{filename} = "t/data/test.txt";
    ensure_directories_exist($self->{filename});

    open(FH, '>', $self->{filename}) or fail sprintf("unable to open file for writting: %s", $!);
    for(my $index = 1; $index < 6; $index++) {
	print FH sprintf("Number %d\n", $index);
    }
    close(FH) or fail sprintf("unable to close file: %s", $!);

    is(file_contents($self->{filename}),
       "Number 1\nNumber 2\nNumber 3\nNumber 4\nNumber 5\n");
}
