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

use KSM::Logger ':all';
use KSM::Helper ':all';

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

sub test_returns_result_of_function : Tests {
    is(with_locked_file(__FILE__,
			sub {
			    "some value from function";
			}),
       "some value from function");
}

sub test_croaks_if_unable_to_open : Tests {
    eval {
	with_locked_file("/root/does/not/exist",
			 sub {
			     1;
			 });
    };
    like($@, qr/^unable to open/);
}

sub test_croaks_when_second_argument_not_function : Tests {
    eval { with_locked_file(__FILE__, "something not a function") };
    like($@, qr/ought to be a function/);
}

sub test_logs_actions_when_called_function_succeeds : Tests {
    my $log = with_captured_log(
	sub {
	    with_locked_file(__FILE__,
			     sub {
				 info("some action logged by client code");
			     });
	});
    like($log, qr/getting exclusive lock/);
    like($log, qr/have exclusive lock/);
    like($log, qr/released exclusive lock/);
    like($log, qr/some action logged by client code/);
}

sub test_croaks_if_function_croaks : Tests {
    eval {
	with_locked_file(__FILE__,
			 sub {
			     croak("my belly aches!");
			 });
    };
    like($@, qr/my belly aches!/);
}

sub test_releases_lock_if_function_croaks : Tests {
    my $log = with_captured_log(
	sub {
	    eval {
		with_locked_file(__FILE__,
				 sub {
				     croak("my belly aches!");
				 });
	    };
	});
    like($log, qr/released exclusive lock/);
}
