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

use Capture::Tiny qw(capture);
use Fcntl qw(:flock);
use POSIX;
use KSM::Helper qw(:all);

########################################

sub cleanup_before_each_test : Tests(setup) {
    system("rm -rf t/data");
}

sub cleanup_after_all_tests : Tests(shutdown) {
    system("rm -rf t/data");
}

########################################

sub test_with_timeout_returns_the_result_of_the_invoked_function : Tests {
    my $result = eval {
	with_timeout("unexpected timeout",
		     1, sub { 42; });
    };
    is($result, 42, $@);
}

sub test_with_timeout_expired : Tests {
    # catches the timeout
    my $result = eval {
        with_timeout("expected timeout",
		     1, 
		     sub {
			 diag "waiting for timeout protection";
			 sleep 2;
			 42;
		     });
    };
    like($@, qr/^expected timeout/);
    isnt($result, 42, $@);
}

sub test_with_timeout_works_with_backtick_call : Tests {
    # when no timeout, returns the result of the invoked function
    is(with_timeout("unexpected timeout during test",
		    1, sub { `id -u`; }),
       `id -u`);

    # catches the timeout
    eval {
        diag "sleeping 2 secs to check timeout protection";
        with_timeout("expected timeout during test",
		     1, sub { `sleep 2 ; id -u`; });
    };
    like($@, qr/^expected timeout during/);
}

sub test_with_timeout_works_with_system_call : Tests {
    # when no timeout, returns the result of the invoked function
    is(with_timeout("unexpected timeout during test",
		    1, sub { system("id -u"); }),
       0);

    # catches the timeout
    eval {
        diag "sleeping 2 secs to check timeout protection";
        with_timeout("expected timeout during test",
		     1, sub { system("sleep 2 ; id -u"); });
    };
    like($@, qr/^expected timeout during/);
}

########################################

sub test_with_locked_file : Tests {
    my $file;

    $file = `mktemp`;
    chomp $file;

    is(with_locked_file($file,
			sub {
			    "lock obtained";
			}),
       "lock obtained");
    
    unlink($file) if -e $file;
}

sub test_with_locked_file_dies_if_unable_to_open : Tests {
    my ($stdout,$stderr,@result) = capture {
        my $file;
        eval {
            $file = "/root/does/not/exist";
            chomp $file;
            eval {
                with_locked_file($file,
                                 sub {
                                     1;
                                 });
            };
            like($@, qr/^unable to open/);
        };
        
        unlink($file) if -e $file;
    };
    like($stderr, qr|unable to open|);
    is($stdout, "");
}

sub test_with_locked_file_dies_if_already_locked : Tests {
    my ($stdout,$stderr,@result) = capture {
        my $file;
        eval {
            chomp($file = `mktemp`);
            open(FILE, '<', $file)
                or fail sprintf('unable to open: [%s]: %s', $file, $!);
            flock(FILE, LOCK_EX | LOCK_NB)
                or fail sprintf('unable to lock: [%s]: %s', $file, $!);
            eval {
                with_locked_file($file,
                                 sub {
                                     1;
                                 });
            };
            like($@, qr/^unable to lock/);
        };
        
        unlink($file);
    };
    like($stderr, qr|unable to lock|);
    is($stdout, "");
}
