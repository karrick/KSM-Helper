#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use Carp;
use File::Path;
use KSM::Helper qw(:all);
use KSM::Logger ':all';
use POSIX ();

########################################

sub chdir_to_test_data_directory : Tests(setup) {
    my ($self) = @_;
    $self->{start_directory} = POSIX::getcwd();
    chomp($self->{dir} = `mktemp -d`);
}

sub remove_test_artifact_and_return_to_start_directory : Tests(teardown) {
    my ($self) = @_;
    chdir($self->{start_directory});
    File::Path::rmtree($self->{dir}) if -d $self->{dir};
}

########################################
# with_captured_log

sub with_captured_log {
    my $function = shift;
    # remaining args for function

    with_temp(
	sub {
	    my $logfile = shift;
	    KSM::Logger::initialize({level => KSM::Logger::DEBUG,
				     filename_template => $logfile,
				     reformatter => sub {
					 my ($level,$msg) = @_;
					 croak("undefined level") if !defined($level);
					 croak("undefined msg") if !defined($msg);
					 sprintf("%s: %s", $level, $msg);
				     }});
	    eval { &{$function}(@_) };
	    # diag sprintf("READING LOG FILE: %s", $logfile);
	    file_contents($logfile);
	});
}

########################################

# For each circumstance:
# 1.  Log both directory changes
# 2.  Log warnings and errors
# 3.  Change directory back to original directory (???: original missing???)

sub test_croaks_when_second_argument_not_function : Tests {
    eval { with_cwd("/tmp", "something not a function") };
    like($@, qr/ought to be a function/);
}

sub test_croaks_when_cannot_change_to_specified_directory : Tests {
    with_captured_log(
	sub {
	    eval {with_cwd('/root', sub {1})};
	    like($@, qr/unable to change directory/);
	    like($@, qr/Permission denied/);
	});
}

sub test_croaks_when_cannot_create_specified_directory : Tests {
    with_captured_log(
	sub {
	    eval {with_cwd('/root/foo', sub {1})};
	    like($@, qr/unable to change directory/);
	    like($@, qr/Permission denied/);
	});
}

sub test_returns_result_of_function : Tests {
    with_captured_log(
	sub {
	    is(with_cwd("/tmp", sub {"some value from function"}),
	       "some value from function");
	});
}

sub test_logs_if_original_directory_missing_when_function_ends : Tests {
    my ($self) = @_;

    chomp(my $other = `mktemp -d`);
    my $log = with_captured_log(
	sub {
	    chdir($other) or fail sprintf("unable to chdir [%s]", $other);
	    with_cwd($self->{dir},
		     sub {
			 system("rm -rf $other");
		     });
	});
    like($log, qr/unable to return to previous directory/);
    like($log, qr/No such file or directory/);
}

sub test_if_function_succeeds : Tests {
    my ($self) = @_;
    my $log = with_captured_log(
	sub {
	    is(with_cwd($self->{dir}, 
			sub {
			    is($self->{dir}, POSIX::getcwd(), "should change directory");
			    "some value"
			}),
	       "some value",
	       "should return function value");
	    is($self->{start_directory}, POSIX::getcwd(),
	       "should return to start directory");
	});
    like($log, qr|cwd: \[$self->{dir}\]|);
    like($log, qr|cwd: \[$self->{start_directory}\]|);
}

sub test_if_function_croaks : Tests {
    my ($self) = @_;
    my $log = with_captured_log(
	sub {
	    with_cwd($self->{dir}, sub {
		is($self->{dir}, POSIX::getcwd(), "should change directory");
		die "burp!"
		     });
	    like($@, qr/burp!/, "should recroak");
	    is($self->{start_directory}, POSIX::getcwd(),
	       "should return to start directory");
	});
    like($log, qr|cwd: \[$self->{dir}\]|);
    like($log, qr|cwd: \[$self->{start_directory}\]|);
}

sub test_should_create_directory_if_not_exist : Tests {
    my ($self) = @_;
    my $other = sprintf("%s/other", $self->{dir});
    my $log = with_captured_log(
	sub {
	    with_cwd($other, sub {
		is($other, POSIX::getcwd(), "should change directory");
		     });
	    is($self->{start_directory}, POSIX::getcwd(),
	       "should return to start directory");
	});
    like($log, qr|No such file or directory|);
    like($log, qr|cwd: \[$other\]|);
    like($log, qr|cwd: \[$self->{start_directory}\]|);
}
