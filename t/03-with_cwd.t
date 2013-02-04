#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Carp;
use File::Spec;
use File::Temp qw(tempdir tempfile);
use Test::Class;
use Test::More;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use File::Path;
use POSIX;

use KSM::Logger ':all';
use KSM::Helper ':all';

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
# with_captured_log

sub with_captured_log(&) {
    my $function = shift;
    # remaining args for function
    with_temp {
	my (undef,$logfile) = @_;
	KSM::Logger::initialize({level => KSM::Logger::DEBUG,
				 filename_template => $logfile,
				 reformatter => sub {
				     my ($level,$msg) = @_;
				     croak("undefined level") if !defined($level);
				     croak("undefined msg") if !defined($msg);
				     sprintf("%s: %s", $level, $msg);
				 }});
	eval { $function->(@_) };
	file_read($logfile);
    };
}

########################################

# For each circumstance:
# 1.  Log both directory changes
# 2.  Log warnings and errors
# 3.  Change directory back to original directory (???: original missing???)

sub test_dies_when_cannot_change_to_specified_directory : Tests {
    with_captured_log {
	eval {with_cwd(sprintf("%s/foo", File::Spec->rootdir()), sub {1})};
	like($@, qr|cannot change directory|);
	like($@, qr|Permission denied|);
    };
}

sub test_dies_when_cannot_create_specified_directory : Tests {
    with_captured_log {
	eval {with_cwd(sprintf("%s/foo", File::Spec->rootdir()), sub {1})};
	like($@, qr|cannot change directory|);
	like($@, qr|Permission denied|);
    };
}

sub test_changes_working_directory : Tests {
    my ($self) = @_;
    with_captured_log {
	with_cwd($self->{dir},
		 sub {
		     is(POSIX::getcwd(), $self->{dir});
		 });
    };
}

sub test_returns_result_of_function : Tests {
    with_captured_log {
	is(with_cwd(File::Spec->tmpdir(), sub {"some value from function"}),
	   "some value from function");
    };
}

sub test_logs_if_original_directory_missing_when_function_ends : Tests {
    my ($self) = @_;

    my $other = File::Temp::tempdir();
    my $log = with_captured_log {
	chdir($other) or fail sprintf("cannot chdir [%s]", $other);
	with_cwd($self->{dir},
		 sub {
		     File::Path::rmtree($other);
		 });
    };
    like($log, qr/cannot return to previous directory/);
    like($log, qr/No such file or directory/);
}

sub test_if_function_succeeds : Tests {
    my ($self) = @_;
    my $dir = POSIX::getcwd();
    my $log = with_captured_log {
	is(with_cwd($self->{dir},
		    sub {
			"some value";
		    }),
	   "some value",
	   "should return function value");
	is(POSIX::getcwd(), $dir,
	   "should return to start directory");
    };
    like($log, qr|cwd: \[$self->{dir}\]|);
    like($log, qr|cwd: \[$dir\]|);
}

sub test_if_function_dies : Tests {
    my ($self) = @_;
    my $dir = POSIX::getcwd();
    my $log = with_captured_log {
	with_cwd($self->{dir},
		 sub {
		     die "burp";
		 });
	like($@, qr|burp|, "ought to die");
	is(POSIX::getcwd(), $dir,
	   "ought chdir back to start directory");
    };
    like($log, qr|cwd: \[$self->{dir}\]|);
    like($log, qr|cwd: \[$dir\]|);
}

sub test_should_create_directory_if_not_exist : Tests {
    my ($self) = @_;
    my $dir = POSIX::getcwd();
    my $other = sprintf("%s/other", $self->{dir});
    my $log = with_captured_log {
	with_cwd($other,
		 sub {
		     ok(-d $other);
		 });
	is(POSIX::getcwd(), $dir,
	   "should return to start directory");
    };
    like($log, qr|cwd: \[$other\]|);
    like($log, qr|cwd: \[$dir\]|);
}
