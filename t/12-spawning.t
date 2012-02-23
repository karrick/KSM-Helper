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

sub with_captured_log {
    my $function = shift;
    # remaining args for function

    with_temp(
	sub {
	    my $logfile = shift;
	    # remaining args for function

	    # KSM::Logger::level(KSM::Logger::DEBUG);
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
# with_timeout_spawn_child

sub test_with_timeout_spawn_child_validates_child_hash {
    with_captured_log(
	sub {
	    eval {
		with_timeout_spawn_child();
	    };
	    like($@, qr/child should be reference to a hash/);
	});

    with_captured_log(
	sub {
	    eval {
		with_timeout_spawn_child({});
	    };
	    like($@, qr/child name should be string/);
	});

    with_captured_log(
	sub {
	    eval {
		with_timeout_spawn_child({name => 'foo'});
	    };
	    like($@, qr/child function should be a function/);
	});

    with_captured_log(
	sub {
	    eval {
		with_timeout_spawn_child({name => 'foo', function => sub { 1 }, 
					  args => 1});
	    };
	    like($@, qr/child args should be reference to array/);
	});
}

sub test_with_timeout_spawn_child_decorates_child_hash {
    with_captured_log(
	sub {
	    my $child = with_timeout_spawn_child({name => 'foo',
						  function => sub { 1 }});
	    isnt($child->{pid}, undef, "should have a pid");
	    isnt($child->{started}, undef, "should have start time");
	    isnt($child->{ended}, undef, "should have end time");
	    isnt($child->{duration}, undef, "should have duration time");
	    ok($child->{duration} >= 0, "duration should be numerical");
	});
}

sub test_with_timeout_spawn_child_logs {
    my $logs;
    $logs = with_captured_log(
	sub {
	    my $child = with_timeout_spawn_child({name => 'foo',
						  function => sub { 1 }});
	});
    like($logs, qr/INFO: spawned child \d+ \(foo\)/);
    like($logs, qr/INFO: child \d+ \(foo\) terminated status code 0/);

    $logs = with_captured_log(
	sub {
	    my $child = with_timeout_spawn_child({name => 'foo',
						  function => sub { exit 1 }});
	});
    like($logs, qr/INFO: spawned child \d+ \(foo\)/);
    like($logs, qr/WARNING: child \d+ \(foo\) terminated status code 1/);

    $logs = with_captured_log(
	sub {
	    my $child = with_timeout_spawn_child({name => 'foo',
						  function => sub { die("TEST") }});
	});
    like($logs, qr/INFO: spawned child \d+ \(foo\)/);
    like($logs, qr/ERROR: error while invoking child function \(foo\): TEST/);
    like($logs, qr/WARNING: child \d+ \(foo\) terminated status code 1/);
}

sub test_with_timeout_spawn_times_out_child {
    my $logs;
    $logs = with_captured_log(
	sub {
	    my $child = with_timeout_spawn_child({name => 'foo',
						  function => sub { sleep 30 },
						  timeout => 1});
	});
    like($logs, qr/INFO: spawned child \d+ \(foo\) with 1 second timeout/);
    like($logs, qr/INFO: timeout: sending child \d+ \(foo\) the TERM signal after 1 seconds/);
    like($logs, qr/WARNING: child \d+ \(foo\) received signal 15 and terminated status code 0/);
}

sub test_with_timeout_spawn_relays_int_and_term_signals_to_child {
    my ($child,$logs);

    foreach my $signal (qw(TERM INT)) {
	my $handler = sub { info("pid %d received %s signal", $$, $signal) ; exit };
	local $SIG{$signal} = $handler;

	$logs = with_captured_log(
	    sub {
		if(my $pid = fork) {
		    diag sprintf("testing %s signal handling", $signal);
		    sleep 1;
		    kill($signal, $pid);
		    sleep 1;

		    # ensure child gone
		    ok(!is_pid_still_alive($pid), sprintf("pid should be gone: %d", $pid));

		    # ensure grandchild gone
		    chomp(my $results = `pgrep -lf foobarbaz`);
		    unlike($results, qr/\d+ foobarbaz/, "should not see grandchild in pgrep output");
		} elsif(defined($pid)) {
		    $child = with_timeout_spawn_child({name => 'foobarbaz',
						       function => sub { sleep 30 }});
		    fail("should not be here");
		    exit;
		} else {
		    fail sprintf("unable to fork: %s", $!);
		}
	    });

		# FIXME: error if client code was accepting other
		# signals: don't want to term child if USR1 was
		# received and handled...
		# CONSIDER: using $respawn as flag to determin

	is_deeply($SIG{$signal}, $handler, sprintf("should have restored %s signal handler", $signal));
	unlike($logs, qr/unable to fork/);
	like($logs, qr/INFO: spawned child \d+ \(foobarbaz\)/);
	like($logs, qr/INFO: received $signal signal/);
	like($logs, qr/INFO: timeout: sending child \d+ \(foobarbaz\) the TERM signal/);
	like($logs, qr/WARNING: child \d+ \(foobarbaz\) received signal 15 and terminated status code 0/);
	like($logs, qr/INFO: all children terminated: exiting/);
	unlike($logs, qr/should not be here/);
	unlike($logs, qr/WARNING: Use of uninitialized value/);
    }
}

########################################

KSM::Helper::activate_reaper();
test_reaper();
test_collect_child_stats();
test_log_child_termination_paremeter_checking();
test_helper_with_captured_log();
test_log_child_termination_status_zero();
test_log_child_termination_status_twelve();
test_log_child_termination_status_term_signal();
test_log_child_termination_status_term_signal_and_non_zero_exit();
test_timeout_child_sends_the_term_signal_and_logs_event();
test_with_timeout_spawn_child_validates_child_hash();
test_with_timeout_spawn_child_decorates_child_hash();
test_with_timeout_spawn_child_logs();
test_with_timeout_spawn_times_out_child();
test_with_timeout_spawn_relays_int_and_term_signals_to_child();
done_testing();
