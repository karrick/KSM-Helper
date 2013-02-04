#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

use Carp;
use Capture::Tiny qw(capture);
use KSM::Logger qw(:all);

use KSM::Helper qw(:all);

########################################
# HELPERS

sub is_pid_still_alive {
    my ($pid) = @_;
    kill(0, $pid);
}

########################################

sub with_nothing_out(&) {
    my ($code) = @_;
    my ($stdout,$stderr,$result) = capture {
	$code->();
    };
    is($stdout, "");
    is($stderr, "");
    $result;
}

sub with_captured_log(&) {
    my $function = shift;
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
	eval { $function->() };
	file_read($logfile);
    };
}

sub test_helper_with_captured_log {
    is(with_captured_log {
	info("FIXME");
       },
       "INFO: FIXME\n");

    is(with_captured_log {
	warning("This is a warning");
       },
       "WARNING: This is a warning\n");
}
test_helper_with_captured_log();

########################################
# spawn

sub test_spawn_dies_if_host_and_not_array {
    eval {spawn(sub { 42; }, {host => "host"})};
    like($@, qr|cannot change host without a command line list|);
}
test_spawn_dies_if_host_and_not_array();

sub test_spawn_dies_if_user_and_not_array {
    eval {spawn(sub { 42; }, {user => "user"})};
    like($@, qr|cannot change user without a command line list|);
}
test_spawn_dies_if_user_and_not_array();

sub test_spawn_dies_if_neither_array_nor_code {
    eval {spawn("scalar")};
    like($@, qr|nothing to execute: no function or list|);
}
test_spawn_dies_if_neither_array_nor_code();

sub test_spawn_accepts_code_reference {
    my $result = spawn(sub {42});
}
test_spawn_accepts_code_reference();

sub test_spawn_returns_time_information {
    my $start = time();
    my $result = spawn(sub {42;}, {timeout => 5});
    my $end = time();
    ok($start <= $result->{started}, "should have start time");
    ok($result->{duration} >=0, "should have numerical duration time");
    ok($result->{ended} <= $end, "should have ended time");
}
test_spawn_returns_time_information();

sub test_spawn_accepts_command_line_list {
    spawn(['bash','-c','true']);
}
test_spawn_accepts_command_line_list();

sub test_spawn_handles_die_inside_code {
    my ($stdout,$stderr,@result) = capture {
	spawn(sub { die "suicide" });
    };
    is($result[0]->{status}, 1);
    is($stdout, "");
    like($stderr, qr|suicide|);
}
test_spawn_handles_die_inside_code();

sub test_spawn_handles_fail_to_exec {
    my ($stdout,$stderr,@result) = capture {
	spawn(['does-not-exist']);
    };
    is($result[0]->{status}, 1);
    is($stdout, "");
    like($stderr, qr|No such file or directory|);
}
test_spawn_handles_fail_to_exec();

sub test_spawn_returns_exit_status {
    my $result;

    $result = spawn(['bash','-c','true']);
    is($result->{status}, 0);

    $result = spawn(['bash','-c','false']);
    is($result->{status}, 1);

    $result = spawn(sub {exit(42)});
    is($result->{status}, 42);
}
test_spawn_returns_exit_status();

sub test_spawn_waits_patiently {
    my $start = time();
    my $result = spawn(sub { sleep 1 });
    my $end = time();
    ok(($end - $start) >= 1);
}
test_spawn_waits_patiently();

sub test_spawn_accepts_timeout {
    my $start = time();
    my $result = spawn(sub { sleep 60 }, {timeout => 1});
    my $end = time();
    ok(($end - $start) >= 1);
    ok(($end - $start) <= 2);
}
test_spawn_accepts_timeout();

sub test_spawn_times_out_child_with_term_signal_and_returns_signal_received_by_child {
    my $result = spawn(
	['sleep','3'],
	{timeout => 1});
    is($result->{signal}, 15);
}
test_spawn_times_out_child_with_term_signal_and_returns_signal_received_by_child();

sub test_spawn_resets_signal_handlers_before_invoking_child {
    local $SIG{TERM} = sub { exit(13) };
    my $result = spawn(sub {sleep 3}, {timeout => 1});
    isnt($result->{status}, 13);
    is(ref($SIG{TERM}), 'CODE');
}
test_spawn_resets_signal_handlers_before_invoking_child();

sub test_spawn_without_stdout_handler_directs_child_stdout_to_its_stdout_1 {
    my ($stdout,$stderr,@result) = capture {
	spawn(['echo','foo']);
    };
    is($stdout, "foo\n");
    is($stderr, "");
}
test_spawn_without_stdout_handler_directs_child_stdout_to_its_stdout_1();

sub test_spawn_without_stdout_handler_directs_child_stdout_to_its_stdout {
    my ($stdout,$stderr,@result) = capture {
	spawn(['printf','%s\n%s\n','foo','bar']);
    };
    is($stdout, "foo\nbar\n");
    is($stderr, "");
}
test_spawn_without_stdout_handler_directs_child_stdout_to_its_stdout();

sub test_spawn_handles_trailing_data_after_last_newline {
    my ($stdout,$stderr,@result) = capture {
	spawn(['printf','%s\n%s','foo','bar']);
    };
    is($stdout, "foo\nbar");
    is($stderr, "");
}
test_spawn_without_stdout_handler_directs_child_stdout_to_its_stdout();

sub test_spawn_with_stdout_handler_directs_child_stdout_to_handler {
    my ($out,$err) = ("","");
    my ($stdout,$stderr,@result) = capture {
	spawn(['printf','%s\n%s\n','foo','bar'],
	      { stdout_handler => sub { $out .= shift } });
    };
    is($stdout, "");
    is($stderr, "");
    is($out, "foo\nbar\n");
}
test_spawn_with_stdout_handler_directs_child_stdout_to_handler();

sub test_with_capture_spawn {
    my $child = with_capture_spawn(sub {
	print STDOUT "foo\n";
	print STDERR "bar\n";
				   });
    is($child->{stdout}, "foo\n");
    is($child->{stderr}, "bar\n");
    ok(defined($child->{status}));
    ok(defined($child->{signal}));
}
test_with_capture_spawn();

sub test_spawn_bang {
    spawn_bang(sub {42});

    my ($stdout,$stderr,@result) = capture {
	eval {spawn_bang(sub {die "suicide"}, {name => 'foo'})};
	like($@, qr|cannot foo|);
    };
    is($stdout, "");
    like($stderr, qr|suicide|);
}
test_spawn_bang();

########################################

sub test_with_logging_spawn_logs_execution_of_name {
    my $log = with_captured_log {
	with_logging_spawn(sub {42}, {name => "TEST1"});
    };
    like($log, qr|executing TEST1|);
}
test_with_logging_spawn_logs_execution_of_name();

sub test_with_logging_spawn_can_log_command_line {
    my $log = with_captured_log {
	with_logging_spawn(
	    ['echo','foo','bar'],
	    {name => 'TEST3', log_command_line => 1})
    };
    like($log, qr|executing TEST3: \(echo foo bar\)|);
}
test_with_logging_spawn_can_log_command_line();

sub test_with_logging_spawn_redirects_stdout_and_stderr {
    my $log = with_captured_log {
	with_logging_spawn(
	    sub {
		print STDOUT "stdout\n";
		print STDERR "stderr\n";
	    },
	    {name => 'TEST2'})
    };
    like($log, qr|INFO: TEST2: stdout|);
    like($log, qr|WARNING: TEST2: stderr|);
}
test_with_logging_spawn_redirects_stdout_and_stderr();

########################################

done_testing();
