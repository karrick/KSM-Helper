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

sub file_contents {
    my ($name) = @_;
    local $/;
    open(FH, '<', $name) or fail sprintf("unable to open file %s: %s", $name, $!);
    <FH>;
}

sub ensure_log_entry {
    my $expected = shift;
    my $function = shift;
    # remaining args for function

    with_temp(sub {
	my $log = shift;
	# remaining args for function

	KSM::Logger::filename_template($log);
	KSM::Logger::reformatter(sub {
	    my ($level,$msg) = @_; 
	    sprintf("%s: %s", $level, $msg);
				 });
	eval { &{$function}(@_) };
	is($@, '', "should not have reported error");
	# diag sprintf("checking contents of %s", $log);
	is(file_contents($log), $expected, sprintf("file_contents do not match: %s", $log));
	      });
}

########################################

sub test_reaper {
    if(my $pid = fork) {
    	diag "sleeping 2 seconds to test REAPER";
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

sub test_helper_ensure_log_entry {
    ensure_log_entry("INFO: FIXME\n", 
		     sub {
			 info("FIXME");
		     });
    ensure_log_entry("WARNING: This is a warning\n", 
		     sub {
			 warning("This is a warning");
		     });
}

sub test_log_child_termination_status_zero {
    ensure_log_entry("INFO: child 999 (foo) terminated status code 0\n",
		     sub {
			 KSM::Helper::log_child_termination({pid => 999, duration => 35, name => 'foo', status => 0});
		     });
}

sub test_log_child_termination_status_twelve {
    ensure_log_entry("WARNING: child 999 (foo) terminated status code 12\n",
		     sub {
			 KSM::Helper::log_child_termination({pid => 999, duration => 35, name => 'foo', status => (12 << 8)});
		     });
}

sub test_log_child_termination_status_term_signal {
    ensure_log_entry("WARNING: child 999 (foo) received signal 15 and terminated status code 0\n",
		     sub {
			 KSM::Helper::log_child_termination({pid => 999, duration => 35, name => 'foo', status => 15});
		     });
}

sub test_log_child_termination_status_term_signal_and_non_zero_exit {
    ensure_log_entry("WARNING: child 999 (foo) received signal 15 and terminated status code 12\n",
		     sub {
			 KSM::Helper::log_child_termination({pid => 999, duration => 35, name => 'foo', 
							     status => ((12 << 8) + 15)});
		     });
}

########################################

KSM::Helper::activate_reaper();
test_reaper();
test_collect_child_stats();
test_log_child_termination_paremeter_checking();
test_helper_ensure_log_entry();
test_log_child_termination_status_zero();
test_log_child_termination_status_twelve();
test_log_child_termination_status_term_signal();
test_log_child_termination_status_term_signal_and_non_zero_exit();
done_testing();
