#!/usr/bin/env perl

use utf8;
# use diagnostics;
use strict;
use warnings;
use Carp;
use Test::More;
# use Test::Class;
# use base qw(Test::Class);
# END { Test::Class->runtests }

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

ok(is_command_line_running(__FILE__));
ok(!is_command_line_running("foobarbaz"));

sub is_child_running {
    my ($child) = @_;
    (is_command_line_running(join(' ', @{$child->{list}}))
     ? 1
     : 0);
}

# sub send_signal_to_child {
#     my ($signal,$child) = @_;
#     my $command_line = shell_quote(join(' ', @{$child->{list}}));
#     my $result = `pkill -$signal -f $command_line`;
#     ($result =~ /\d+/ ? 1 : 0);
# }

########################################

sub with_captured_log {
    my $function = shift;
    # remaining args for function

    with_temp(
	sub {
	    my (undef,$logfile) = @_;
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
	    file_contents($logfile);
	});
}
my $log;

########################################
# croaks when fail argument check

with_captured_log(
    sub {
	eval {with_timeout_spawn_child()};
	like($@, qr/nothing to execute/);
    });

with_captured_log(
    sub {
	eval {with_timeout_spawn_child('frumple')};
	like($@, qr/nothing to execute/);
    });

with_captured_log(
    sub {
	eval {with_timeout_spawn_child([])};
	like($@, qr/nothing to execute/);
    });

with_captured_log(
    sub {
	eval {with_timeout_spawn_child({})};
	like($@, qr/nothing to execute/);
    });

with_captured_log(
    sub {
	eval {with_timeout_spawn_child({name => 'frumple'})};
	like($@, qr/nothing to execute/);
    });

########################################

sub ensure_child_return_sanity {
    my ($child) = @_;

    isnt($child->{name}, undef, "should keep its name");
    ok((ref($child->{list}) eq 'ARRAY'
	|| ref($child->{function}) eq 'CODE'),
       "should have either list or function");

    isnt($child->{pid}, undef, "should have pid");
    isnt($child->{status}, undef, "should have status");
    isnt($child->{started}, undef, "should have start time");
    isnt($child->{ended}, undef, "should have end time");
    isnt($child->{duration}, undef, "should have duration time");

    ok(POSIX::strftime("%s", gmtime) >= $child->{started}, "should have start time");
    ok(POSIX::strftime("%s", gmtime) >= $child->{ended}, "should have end time");
    ok(POSIX::strftime("%s", gmtime) >= $child->{duration}, "should have duration time");
    ok($child->{duration} >= 0, "duration should be numerical");
}

########################################
# croaks and logs if unable to exec program

$log = with_captured_log(
    sub {
	no warnings;
	my $name = 'invalid-tester';
	my $list = ['ignore-cant-exec-warning'];
	my $child = with_timeout_spawn_child({name => $name, list => $list});
	# The child process will attempt to exec and die.  parent will
	# only know by fetching the status code; the child die will
	# not come back to here.
	ensure_child_return_sanity($child);
	isnt($child->{status}, 0, "should have failed status");
    });
like($log, qr/INFO: spawned child \d+ \(invalid-tester\)/);
like($log, qr/ERROR: unable to exec \(invalid-tester\): \(ignore-cant-exec-warning\): No such file or directory/);
like($log, qr/WARNING: child \d+ \(invalid-tester\) terminated status code 1/);

########################################
# logs and detects result of failed child program (/bin/false)

$log = with_captured_log(
    sub {
	my $name = 'false-tester';
	my $list = ['/bin/false'];
	my $child = with_timeout_spawn_child({name => $name, list => $list});
	ensure_child_return_sanity($child);
	isnt($child->{status}, 0, "should have failed status");
    });
like($log, qr/INFO: spawned child \d+ \(false-tester\)/);
like($log, qr/WARNING: child \d+ \(false-tester\) terminated status code 1/);

########################################
# logs and detects result of successful child program (/bin/true)

$log = with_captured_log(
    sub {
	my $name = 'true-tester';
	my $list = ['/bin/true'];
	my $child = with_timeout_spawn_child({name => $name, list => $list, timeout => 10});
	ensure_child_return_sanity($child);
	is($child->{status}, 0, "should have successful status");
	ok($child->{duration} <= 1, "duration should be correct");
    });
like($log, qr/INFO: spawned child \d+ \(true-tester\)/);
like($log, qr/INFO: child \d+ \(true-tester\) terminated status code 0/);

########################################
# logs and detects result of successful but slow child program (/bin/sleep)

$log = with_captured_log(
    sub {
	my $name = 'short-tester';
	my $list = ['sleep','2'];
	my $child = with_timeout_spawn_child({name => $name, list => $list});
	ensure_child_return_sanity($child);
	is($child->{status}, 0, "should have successful status");
	ok($child->{duration} >= 2, "duration should be correct");
	ok($child->{duration} <= 3, "duration should be correct");
    });
like($log, qr/INFO: spawned child \d+ \(short-tester\)/);
like($log, qr/INFO: child \d+ \(short-tester\) terminated status code 0/);

########################################
# logs and detects result of timed out termination of slow child program (/bin/sleep)

$log = with_captured_log(
    sub {
	KSM::Logger::level(KSM::Logger::DEBUG);
	my $name = 'timeout-tester';
	my $list = ['sleep','5'];
	my $child = with_timeout_spawn_child({name => $name, list => $list, timeout => 1});
	ensure_child_return_sanity($child);
	is($child->{status}, 15, "should reflect signal 15");
	ok($child->{duration} >= 1, "duration should be correct");
	ok($child->{duration} <= 2, "duration should be correct");
    });
like($log, qr/INFO: spawned child \d+ \(timeout-tester\) with 1 second timeout/);
like($log, qr/INFO: timeout: sending child \d+ \(timeout-tester\) the TERM signal after 1 seconds/);
like($log, qr/WARNING: child \d+ \(timeout-tester\) received signal 15 and terminated status code 0/);

########################################
# logs and detects result of successful function

$log = with_captured_log(
    sub {
	my $name = 'okay-function-tester';
	my $function = sub { 1 };
	my $child = with_timeout_spawn_child({name => $name, function => $function, timeout => 10});
	ensure_child_return_sanity($child);
	is($child->{status}, 0, "should have successful status");
	ok($child->{duration} <= 1, "duration should be correct");
    });
like($log, qr/INFO: spawned child \d+ \(okay-function-tester\)/);
like($log, qr/INFO: child \d+ \(okay-function-tester\) terminated status code 0/);

########################################
# logs and detects result of unsuccessful function

$log = with_captured_log(
    sub {
	my $name = 'fail-function-tester';
	my $function = sub { exit 1 };
	my $child = with_timeout_spawn_child({name => $name, function => $function, timeout => 10});
	ensure_child_return_sanity($child);
	isnt($child->{status}, 0, "should have unsuccessful status");
	ok($child->{duration} <= 1, "duration should be correct");
    });
like($log, qr/INFO: spawned child \d+ \(fail-function-tester\)/);
like($log, qr/WARNING: child \d+ \(fail-function-tester\) terminated status code 1/);

########################################
# logs and detects result of dieing function

$log = with_captured_log(
    sub {
	my $name = 'die-function-tester';
	my $function = sub { die("a miserable death") };
	my $child = with_timeout_spawn_child({name => $name, function => $function, timeout => 10});
	ensure_child_return_sanity($child);
	isnt($child->{status}, 0, "should have unsuccessful status");
	ok($child->{duration} <= 1, "duration should be correct");
    });
like($log, qr/INFO: spawned child \d+ \(die-function-tester\)/);
like($log, qr/WARNING: child \d+ \(die-function-tester\) terminated status code \d+/);

########################################

sub run_signal_test {
    my ($signal) = @_;

    my $handler = sub { info("pid %d received %s signal", $$, $signal) # ; exit
    };
    local $SIG{$signal} = $handler;

    my $seconds = 5;
    my $child = {name => "${signal}-tester", list => ['sleep',$seconds]};
    my $signal_should_kill = find($signal, ['INT','TERM'], \&equals);
    my $log = with_captured_log(
	sub {
	    KSM::Logger::level(KSM::Logger::DEBUG);
	    if(is_child_running($child)) {
		fail sprintf("should not see grandchild in pgrep output: %s", $child->{name});
	    }
	    if(my $pid = fork) {
		diag sprintf("testing %s signal handling (should %skill process)", $signal, ($signal_should_kill ? "" : "not "));
		sleep 1;
		ok(is_pid_still_alive($pid), sprintf("pid should be present: %d", $pid));
		ok(is_child_running($child), sprintf("should see grandchild in pgrep output: %s", $child->{name}));
		kill($signal, $pid);
		sleep 1;

		if($signal_should_kill) {
		    ok(!is_pid_still_alive($pid), sprintf("pid should be gone: %d", $pid));
		    ok(!is_child_running($child), sprintf("should not see grandchild in pgrep output: %s", $child->{name}));
		} else {
		    ok(is_pid_still_alive($pid), sprintf("pid should be present: %d", $pid));
		    ok(is_child_running($child), sprintf("should see grandchild in pgrep output: %s", $child->{name}));
		    wait;
		}
	    } elsif(defined($pid)) {
		with_timeout_spawn_child($child);
		exit;
	    } else {
		fail sprintf("unable to fork: %s", $!);
	    }
	});

    is_deeply($SIG{$signal}, $handler, sprintf("should have restored %s signal handler", $signal));
    unlike($log, qr/unable to fork/);
    like($log, qr/INFO: spawned child \d+ \(${signal}-tester\)/);
    if($signal_should_kill) {
    	unlike($log, qr/INFO: pid \d+ received $signal signal/);
	unlike($log, qr/INFO: child \d+ \(${signal}-tester\) terminated status code 0/);

    	like($log, qr/INFO: received $signal signal; preparing to exit/);
    	like($log, qr/INFO: sending child \d+ \(${signal}-tester\) the TERM signal/);
	like($log, qr/WARNING: child \d+ \(${signal}-tester\) received signal 15 and terminated status code 0/);
	like($log, qr/INFO: all children terminated: exiting/);
    } else {
    	like($log, qr/INFO: pid \d+ received $signal signal/);
	like($log, qr/INFO: child \d+ \(${signal}-tester\) terminated status code 0/);

    	unlike($log, qr/INFO: received $signal signal; preparing to exit/);
    	unlike($log, qr/INFO: sending child \d+ \(${signal}-tester\) the TERM signal/);
	unlike($log, qr/WARNING: child \d+ \(${signal}-tester\) received signal 15 and terminated status code 0/);
	unlike($log, qr/INFO: all children terminated: exiting/);
    }
    unlike($log, qr/WARNING: Use of uninitialized value/);
}

foreach (qw(TERM HUP USR1 INT USR2 ALRM)) {
    run_signal_test($_);
}
done_testing();
