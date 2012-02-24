#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Test::More;

########################################

use KSM::Logger qw(:all);
use KSM::Helper qw(:all);

########################################
# HELPERS

sub is_pid_still_alive {
    my ($pid) = @_;
    kill(0, $pid);
}

########################################

sub with_captured_log {
    my $function = shift;
    # remaining args for function

    with_temp(
	sub {
	    my $logfile = shift;
	    # remaining args for function

	    KSM::Logger::filename_template($logfile);
	    KSM::Logger::reformatter(sub {
		my ($level,$msg) = @_; 
		croak("undefined level") unless defined($level);
		croak("undefined msg") unless defined($msg);
		sprintf("%s: %s", $level, $msg);
				     });
	    eval { &{$function}(@_) };
	    is($@, '', "should not have reported error");
	    file_contents($logfile);
	});
}

sub test_helper_with_captured_log {
    is(with_captured_log(
	   sub {
	       info("FIXME");
	   }),
       "INFO: FIXME\n");

    is(with_captured_log(
	   sub {
	       warning("This is a warning");
	   }),
       "WARNING: This is a warning\n");
}

########################################

sub test_reaper {
    if(my $pid = fork) {
    	diag "testing REAPER";
    	sleep 1;
    	kill('TERM', $pid);
    	sleep 1;
    	ok(!is_pid_still_alive($pid), sprintf("pid should be gone: %d", $pid));
    } elsif(defined($pid)) {
    	sleep; # until signal arrives
	fail("should not be here");
	exit;
    } else {
    	fail sprintf("unable to fork: %s", $!);
    }
}

sub test_collect_child_stats {
    # effectively merges hashes together
    is_deeply(KSM::Helper::collect_child_stats({pid => 999, started => 12345, timeout => 60},
					       {status => 256, ended => 23456}),
	      {pid => 999, started => 12345, timeout => 60, status => 256, ended => 23456, duration => (23456 - 12345)});
}

########################################
# log_child_termination

sub test_log_child_termination_paremeter_checking {
    eval {KSM::Helper::log_child_termination()};
    like($@, qr/invalid child/);

    eval {KSM::Helper::log_child_termination('foo')};
    like($@, qr/invalid child/);

    eval {KSM::Helper::log_child_termination([])};
    like($@, qr/invalid child/);

    eval {KSM::Helper::log_child_termination({})};
    like($@, qr/invalid child pid/);

    eval {KSM::Helper::log_child_termination({pid => 999})};
    like($@, qr/invalid child duration/);

    eval {KSM::Helper::log_child_termination({pid => 999, duration => 35})};
    like($@, qr/invalid child name/);

    eval {KSM::Helper::log_child_termination({pid => 999, duration => 35, name => 'foo'})};
    like($@, qr/invalid child status/);
}

sub test_log_child_termination_status_zero {
    is(with_captured_log(
	   sub {
	       KSM::Helper::log_child_termination({pid => 999, duration => 35, name => 'foo', status => 0});
	   }),
       "INFO: child 999 (foo) terminated status code 0\n");
}

sub test_log_child_termination_status_twelve {
    is(with_captured_log(
	   sub {
	       KSM::Helper::log_child_termination({pid => 999, duration => 35, name => 'foo', status => (12 << 8)});
	   }),
       "WARNING: child 999 (foo) terminated status code 12\n");
}

sub test_log_child_termination_status_term_signal {
    is(with_captured_log(
	   sub {
	       KSM::Helper::log_child_termination({pid => 999, duration => 35, name => 'foo', status => 15});
	   }),
       "WARNING: child 999 (foo) received signal 15 and terminated status code 0\n");
}

sub test_log_child_termination_status_term_signal_and_non_zero_exit {
    is(with_captured_log(
	   sub {
	       KSM::Helper::log_child_termination({pid => 999, duration => 35, name => 'foo', 
						   status => ((12 << 8) + 15)});
	   }),
       "WARNING: child 999 (foo) received signal 15 and terminated status code 12\n");
}

########################################
# timeout_child

sub test_timeout_child_sends_the_term_signal_and_logs_event {
    my $child = {name => 'bar', timeout => 30};

    if(my $pid = fork) {
	$child->{pid} = $pid;
	is(with_captured_log(
	       sub {
		   KSM::Helper::timeout_child($child);
	       }),
	   sprintf("INFO: timeout: sending child %d (%s) the TERM signal after %d seconds\n", $pid, $child->{name}, $child->{timeout}));
	sleep 1;
	ok(!is_pid_still_alive($pid), sprintf("pid should be gone: %d", $pid));
    } elsif(defined($pid)) {
	sleep; # until signal arrives
	fail("should not be here");
	exit;
    } else {
	fail sprintf("unable to fork: %s", $!);
    }
}

########################################

test_helper_with_captured_log();

$SIG{CHLD} = \&KSM::Helper::REAPER;
test_reaper();
test_collect_child_stats();

test_log_child_termination_paremeter_checking();
test_log_child_termination_status_zero();
test_log_child_termination_status_twelve();
test_log_child_termination_status_term_signal();
test_log_child_termination_status_term_signal_and_non_zero_exit();

test_timeout_child_sends_the_term_signal_and_logs_event();

done_testing();
