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

use File::Path;
use POSIX;

use KSM::Helper qw(:all);

########################################

use constant TEST_DIR_COUNT => 2;
use constant TEST_DOT_COUNT => 3;

sub tempdir_wrapper_for_mac {
    my $start = POSIX::getcwd();
    chdir(File::Temp::tempdir()) or fail($!);
    my $temp = POSIX::getcwd();
    chdir($start) or fail($!);
    $temp;
}

sub chdir_to_test_data_directory : Test(setup) {
    my ($self) = @_;

    $self->{start_directory} = POSIX::getcwd();

    $self->{source} = tempdir_wrapper_for_mac();
    $self->{destination} = tempdir_wrapper_for_mac();

    my $template = "%s/%sfoo-%d.out";
    my $test_file;

    # create a few regular files in source
    for(my $index = 0; $index < TEST_DIR_COUNT; $index++) {
	$test_file = sprintf($template, $self->{destination}, "", $index);
	open(FILE, '>', $test_file)
	    or fail sprintf('cannot create temp file: [%s]: %s', $test_file, $!);
	print FILE sprintf("I can count to %d!\n", $index);
	close FILE;
    }

    # create a few dot files in destination
    for(my $index = 0; $index < TEST_DOT_COUNT; $index++) {
	$test_file = sprintf($template, $self->{destination}, ".", $index);
	open(FILE, '>', $test_file)
	    or fail sprintf('cannot create temp file: [%s]: %s', $test_file, $!);
	print FILE sprintf("I can count to %d!\n", $index);
	close FILE;
    }
}

sub remove_test_artifact_and_return_to_start_directory : Test(teardown) {
    my ($self) = @_;
    chdir($self->{start_directory});
    File::Path::rmtree($self->{destination}) if -d $self->{destination};
}

########################################

sub test_directory_contents_croaks_when_directory_invalid : Tests {
    eval {directory_contents("t/data/invalid-directory")};
    like($@, qr|No such file or directory|);
}

sub test_directory_contents_assumes_cwd_when_no_argument : Tests {
    my ($self) = @_;

    my $contents = with_cwd($self->{destination},
			    sub {
				directory_contents();
			    });
    is(scalar(@$contents), (TEST_DIR_COUNT + TEST_DOT_COUNT));
}

sub test_directory_contents_works_when_directory_argument_is_dot : Tests {
    my ($self) = @_;

    my $contents = with_cwd($self->{destination},
			    sub {
				directory_contents('.');
			    });
    is(scalar(@$contents), (TEST_DIR_COUNT + TEST_DOT_COUNT));
}

sub test_directory_contents_includes_regular_files : Tests {
    my ($self) = @_;

    my $contents = directory_contents($self->{destination});
    is(scalar(@$contents), (TEST_DIR_COUNT + TEST_DOT_COUNT));

    foreach (@$contents) {
	like($_, qr/\.?foo-\d+\.out$/);
    }
}

sub test_directory_contents_dies_when_lack_permissions : Tests {
    eval {directory_contents('/root')};
    isnt($@, "");
}

sub test_directory_contents_returns_empty_array_when_directory_empty : Tests {
    my ($self) = @_;
    is_deeply(directory_contents($self->{source}), []);
}
