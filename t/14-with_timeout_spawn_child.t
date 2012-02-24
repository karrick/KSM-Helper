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

sub is_command_line_running {
    my ($command_line) = @_;
    $command_line = shell_quote($command_line);
    my $result = `pgrep -f $command_line`;
    ($result =~ /\d+/ ? 1 : 0);
}

sub test_is_command_line_running {
    ok(is_command_line_running(__FILE__));
    ok(!is_command_line_running("foobarbaz"));
}

########################################

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
	    ok(POSIX::strftime("%s", gmtime) >= $child->{started}, "should have start time");
	    is($child->{status}, 0, "should have a status");
	    ok(POSIX::strftime("%s", gmtime) >= $child->{ended}, "should have end time");
	    ok(POSIX::strftime("%s", gmtime) >= $child->{duration}, "should have duration time");
	    ok($child->{duration} >= 0, "duration should be numerical");
	});

    with_captured_log(
	sub {
	    my $child = with_timeout_spawn_child({name => 'foo',
						  function => sub { exit 1 }});
	    isnt($child->{pid}, undef, "should have a pid");
	    ok(POSIX::strftime("%s", gmtime) >= $child->{started}, "should have start time");
	    is($child->{status}, (1 << 8), "should have a status");
	    ok(POSIX::strftime("%s", gmtime) >= $child->{ended}, "should have end time");
	    ok(POSIX::strftime("%s", gmtime) >= $child->{duration}, "should have duration time");
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

sub test_with_timeout_spawn_child_should_not_wait_for_timeout_to_return {
    with_captured_log(
	sub {
	    my $timeout = 5;
	    my $started = POSIX::strftime("%s", gmtime);
	    with_timeout_spawn_child({name => 'TEST IMMEDIATE',
				      timeout => $timeout,
				      function => sub {1}});
	    my $ended = POSIX::strftime("%s", gmtime);
	    ok((($ended - $started) <= $timeout), "should not wait for timeout");
	});
}

sub test_with_timeout_spawn_child_should_not_take_longer_than_timeout {
    with_captured_log(
	sub {
	    my $timeout = 1;
	    my $child = {name => 'TEST SLEEP 3',
			 timeout => $timeout,
			 function => sub {
			     debug("about to sleep: %d", $$);
			     sleep 3;
			 }};
	    my $started = POSIX::strftime("%s", gmtime);
	    with_timeout_spawn_child($child);
	    my $ended = POSIX::strftime("%s", gmtime);
	    ok((($ended - $started) <= ($timeout + 1)), "should not take longer than timeout");
	});
}

sub test_with_timeout_spawn_child_should_not_timeout_if_none_specified {
    with_captured_log(
	sub {
	    my $child = {name => 'TEST SHOULD NOT TIMEOUT',
			 function => sub { sleep 2;}};
	    my $started = POSIX::strftime("%s", gmtime);
	    diag('sleeping 2 seconds TEST SHOULD NOT TIMEOUT');
	    with_timeout_spawn_child($child);
	    my $ended = POSIX::strftime("%s", gmtime);
	    ok((($ended - $started) >= 2), "should not timeout unless specified");
	});
}

########################################

sub run_signal_test {
    my ($signal) = @_;

    my $handler = sub { info("pid %d received %s signal", $$, $signal) ; exit };
    local $SIG{$signal} = $handler;

    my $child = {name => "${signal}-tester", function => sub {sleep 60}};
    my $recursive = find($signal, ['INT','TERM'], \&equals);
    my $logs = with_captured_log(
	sub {
	    if(is_command_line_running($child->{name})) {
		fail sprintf("should not see grandchild in pgrep output: %s", $child->{name});
	    }
	    if(my $pid = fork) {
		diag sprintf("testing %s%s signal handling", ($recursive ? "recursive " : ""), $signal);
		sleep 1;
		ok(is_command_line_running($child->{name}), sprintf("should see grandchild in pgrep output: %s", $child->{name}));
		kill($signal, $pid);
		sleep 1;
		ok(!is_pid_still_alive($pid), sprintf("pid should be gone: %d", $pid));
		if(!$recursive) {
		    ok(is_command_line_running($child->{name}), sprintf("should see grandchild in pgrep output: %s", $child->{name}));
		    system("pkill -f " . shell_quote("${signal}-tester"));
		    sleep 1;
		}
		ok(!is_command_line_running($child->{name}), sprintf("should not see grandchild in pgrep output: %s", $child->{name}));
	    } elsif(defined($pid)) {
		with_timeout_spawn_child($child);
		fail("should not be here");
		exit;
	    } else {
		fail sprintf("unable to fork: %s", $!);
	    }
	});

    is_deeply($SIG{$signal}, $handler, sprintf("should have restored %s signal handler", $signal));
    unlike($logs, qr/unable to fork/);
    like($logs, qr/INFO: spawned child \d+ \(${signal}-tester\)/);
    if($recursive) {
	like($logs, qr/INFO: received $signal signal/);
	like($logs, qr/INFO: timeout: sending child \d+ \(${signal}-tester\) the TERM signal/);
	like($logs, qr/WARNING: child \d+ \(${signal}-tester\) received signal 15 and terminated status code 0/);
	like($logs, qr/INFO: all children terminated: exiting/);
    } else {
	like($logs, qr/INFO: pid \d+ received $signal signal/);
	unlike($logs, qr/INFO: timeout: sending child \d+ \(${signal}-tester\) the TERM signal/);
	unlike($logs, qr/WARNING: child \d+ \(${signal}-tester\) received signal 15 and terminated status code 0/);
	unlike($logs, qr/INFO: all children terminated: exiting/);
    }
    unlike($logs, qr/should not be here/);
    unlike($logs, qr/WARNING: Use of uninitialized value/);
}

########################################

test_is_command_line_running();

test_with_timeout_spawn_child_validates_child_hash();
test_with_timeout_spawn_child_decorates_child_hash();
test_with_timeout_spawn_child_logs();
test_with_timeout_spawn_times_out_child();

test_with_timeout_spawn_child_should_not_wait_for_timeout_to_return();
test_with_timeout_spawn_child_should_not_take_longer_than_timeout();
test_with_timeout_spawn_child_should_not_timeout_if_none_specified();

run_signal_test('TERM');
run_signal_test('INT');
run_signal_test('USR1');
run_signal_test('USR2');
done_testing();
