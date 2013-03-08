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

sub test_helper_with_captured_log : Tests {
    is(with_captured_log {
	info("FIXME");
       },
       "INFO: FIXME\n");

    is(with_captured_log {
	warning("This is a warning");
       },
       "WARNING: This is a warning\n");
}

########################################
# spawn

sub test_spawn_dies_if_host_and_not_array : Tests {
    eval {spawn(sub { 42; }, {host => "host"})};
    like($@, qr|cannot change host without a command line list|);
}

sub test_spawn_dies_if_user_and_not_array : Tests {
    eval {spawn(sub { 42; }, {user => "user"})};
    like($@, qr|cannot change user without a command line list|);
}

sub test_spawn_dies_if_neither_array_nor_code : Tests {
    eval {spawn("scalar")};
    like($@, qr|nothing to execute: no function or list|);
}

sub test_spawn_accepts_code_reference : Tests {
    my $result = spawn(sub {42});
}

sub test_spawn_returns_time_information : Tests {
    my $start = time();
    my $result = spawn(sub {42;}, {timeout => 5});
    my $end = time();
    ok($start <= $result->{started}, "should have start time");
    ok($result->{duration} >=0, "should have numerical duration time");
    ok($result->{ended} <= $end, "should have ended time");
}

sub test_spawn_accepts_command_line_list : Tests {
    spawn(['bash','-c','true']);
}

sub test_spawn_handles_die_inside_code : Tests {
    my ($stdout,$stderr,@result) = capture {
	spawn(sub { die "suicide" });
    };
    is($result[0]->{status}, 1);
    is($stdout, "");
    like($stderr, qr|suicide|);
}

sub test_spawn_handles_fail_to_exec : Tests {
    my ($stdout,$stderr,@result) = capture {
	spawn(['does-not-exist']);
    };
    is($result[0]->{status}, 1);
    is($stdout, "");
    like($stderr, qr|No such file or directory|);
}

sub test_spawn_returns_exit_status : Tests {
    my $result;

    $result = spawn(['bash','-c','true']);
    is($result->{status}, 0);

    $result = spawn(['bash','-c','false']);
    is($result->{status}, 1);

    $result = spawn(sub {exit(42)});
    is($result->{status}, 42);
}

sub test_spawn_waits_patiently : Tests {
    my $start = time();
    my $result = spawn(sub { sleep 1 });
    my $end = time();
    ok(($end - $start) >= 1);
}

sub test_spawn_accepts_timeout : Tests {
    my $start = time();
    my $result = spawn(sub { sleep 60 }, {timeout => 1});
    my $end = time();
    ok(($end - $start) >= 1);
    ok(($end - $start) <= 2);
}

sub test_spawn_times_out_child_with_term_signal_and_returns_signal_received_by_child : Tests {
    my $result = spawn(
	['sleep','3'],
	{timeout => 1});
    is($result->{signal}, 15);
}

sub test_spawn_resets_signal_handlers_before_invoking_child : Tests {
    local $SIG{TERM} = sub { exit(13) };
    my $result = spawn(sub {sleep 3}, {timeout => 1});
    isnt($result->{status}, 13);
    is(ref($SIG{TERM}), 'CODE');
}

sub test_spawn_bang : Tests {
    spawn_bang(sub {42});

    my ($stdout,$stderr,@result) = capture {
	eval {spawn_bang(sub {die "suicide"}, {name => 'foo'})};
	like($@, qr|cannot foo|);
    };
    is($stdout, "");
    like($stderr, qr|suicide|);
}

sub test_spawn_bang_reports_name_of_child_log : Tests {
    spawn_bang(sub {42});

    my ($stdout,$stderr,@result) = capture {
	eval {spawn_bang(sub {die "suicide"},
			 {name => 'foo', child_log => '/tmp/child.log'})};
	like($@, qr|cannot foo|);
	like($@, qr|/tmp/child.log|);
    };
    is($stdout, "");
    like($stderr, qr|suicide|);
}

########################################
# STDOUT and STDERR handling

sub test_spawn_neither_capture_nor_log_does_nothing_with_stdout_and_stderr : Tests {
    my ($stdout,$stderr,$result) = capture {
	my $log = with_captured_log {
	    my $child = spawn(
		sub {
		    print STDOUT "line 1 to stdout\n";
		    print STDOUT "line 2 to stdout";
		    print STDERR "line 1 to stderr\n";
		    print STDERR "line 2 to stderr";
		});
	    ok(!defined($child->{stdout}));
	    ok(!defined($child->{stderr}));
	};
	unlike($log, qr|line 1 to stdout|);
	unlike($log, qr|line 2 to stdout|);
	unlike($log, qr|line 1 to stderr|);
	unlike($log, qr|line 2 to stderr|);
    };
    like($stdout, qr|line 1 to stdout|);
    like($stdout, qr|line 2 to stdout|);
    like($stderr, qr|line 1 to stderr|);
    like($stderr, qr|line 2 to stderr|);
}

sub test_spawn_capture_captures_stdout_and_stderr : Tests {
    my ($stdout,$stderr,$result) = capture {
	my $log = with_captured_log {
	    my $child = spawn(
		sub {
		    print STDOUT "line 1 to stdout\n";
		    print STDOUT "line 2 to stdout";
		    print STDERR "line 1 to stderr\n";
		    print STDERR "line 2 to stderr";
		}, { capture => 1 });
	    like($child->{stdout}, qr|line 1 to stdout|);
	    like($child->{stdout}, qr|line 2 to stdout|);
	    like($child->{stderr}, qr|line 1 to stderr|);
	    like($child->{stderr}, qr|line 2 to stderr|);
	};
	unlike($log, qr|line 1 to stdout|);
	unlike($log, qr|line 2 to stdout|);
	unlike($log, qr|line 1 to stderr|);
	unlike($log, qr|line 2 to stderr|);
    };
    unlike($stdout, qr|line 1 to stdout|);
    unlike($stdout, qr|line 2 to stdout|);
    unlike($stderr, qr|line 1 to stderr|);
    unlike($stderr, qr|line 2 to stderr|);
}

sub test_spawn_log_sends_stdout_and_stderr_to_log : Tests {
    my ($stdout,$stderr,$result) = capture {
	my $log = with_captured_log {
	    my $child = spawn(
		sub {
		    print STDOUT "line 1 to stdout\n";
		    print STDOUT "line 2 to stdout";
		    print STDERR "line 1 to stderr\n";
		    print STDERR "line 2 to stderr";
		}, { log => 1 });
	    ok(!defined($child->{stdout}));
	    ok(!defined($child->{stderr}));
	};
	like($log, qr|line 1 to stdout|);
	like($log, qr|line 2 to stdout|);
	like($log, qr|line 1 to stderr|);
	like($log, qr|line 2 to stderr|);
    };
    unlike($stdout, qr|line 1 to stdout|);
    unlike($stdout, qr|line 2 to stdout|);
    unlike($stderr, qr|line 1 to stderr|);
    unlike($stderr, qr|line 2 to stderr|);
}

sub test_spawn_capture_log_sends_stdout_and_stderr_to_log_and_captures_it : Tests {
    my ($stdout,$stderr,$result) = capture {
	my $log = with_captured_log {
	    my $child = spawn(
		sub {
		    print STDOUT "line 1 to stdout\n";
		    print STDOUT "line 2 to stdout";
		    print STDERR "line 1 to stderr\n";
		    print STDERR "line 2 to stderr";
		}, { capture => 1, log => 1 });
	    like($child->{stdout}, qr|line 1 to stdout|);
	    like($child->{stdout}, qr|line 2 to stdout|);
	    like($child->{stderr}, qr|line 1 to stderr|);
	    like($child->{stderr}, qr|line 2 to stderr|);
	};
	like($log, qr|line 1 to stdout|);
	like($log, qr|line 2 to stdout|);
	like($log, qr|line 1 to stderr|);
	like($log, qr|line 2 to stderr|);
    };
    unlike($stdout, qr|line 1 to stdout|);
    unlike($stdout, qr|line 2 to stdout|);
    unlike($stderr, qr|line 1 to stderr|);
    unlike($stderr, qr|line 2 to stderr|);
}

sub test_spawn_log_logs_command_and_args : Tests {
    with_nothing_out {
	my $log = with_captured_log {
	    my $child = spawn(['echo','foo','bar'],
			      { name => "flubber", log => 1 });
	};
	like($log, qr|executing flubber: \(echo foo bar\)|);
	like($log, qr|INFO.*foo bar|);
    };
}

sub test_spawn_does_not_send_excess_newline_to_stdout : Tests {
    with_nothing_out {
	my $log = with_captured_log {
	    spawn(sub { print STDERR "foo bar\n" },
		  { name => "flubber", log => 1 });
	};
	unlike($log, qr|STDOUT|);
    };
}

sub test_spawn_does_not_send_excess_newline_to_stderr : Tests {
    with_nothing_out {
	my $log = with_captured_log {
	    spawn(sub { print STDOUT "foo bar\n" },
		  { name => "flubber", log => 1 });
	};
	unlike($log, qr|STDERR|);
    };
}

sub test_spawn_without_stdout_handler_directs_child_stdout_to_its_stdout_1 : Tests {
    my ($stdout,$stderr,@result) = capture {
	spawn(['echo','foo']);
    };
    is($stdout, "foo\n");
    is($stderr, "");
}

sub test_spawn_without_stdout_handler_directs_child_stdout_to_its_stdout : Tests {
    my ($stdout,$stderr,@result) = capture {
	spawn(['printf','%s\n%s\n','foo','bar']);
    };
    is($stdout, "foo\nbar\n");
    is($stderr, "");
}

sub test_spawn_handles_trailing_data_after_last_newline : Tests {
    my ($stdout,$stderr,@result) = capture {
	spawn(['printf','%s\n%s','foo','bar']);
    };
    is($stdout, "foo\nbar");
    is($stderr, "");
}

sub test_spawn_with_stdout_handler_directs_child_stdout_to_handler : Tests {
    my ($out,$err) = ("","");
    my ($stdout,$stderr,@result) = capture {
	spawn(['printf','%s\n%s\n','foo','bar'],
	      { stdout_handler => sub { $out .= shift } });
    };
    is($stdout, "");
    is($stderr, "");
    is($out, "foo\nbar\n");
}

sub test_with_capture_spawn : Tests {
    my $child = with_capture_spawn(sub {
	print STDOUT "foo\n";
	print STDERR "bar\n";
				   });
    is($child->{stdout}, "foo\n");
    is($child->{stderr}, "bar\n");
    ok(defined($child->{status}));
    ok(defined($child->{signal}));
}

########################################

sub test_with_logging_spawn_logs_execution_of_name : Tests {
    my $log = with_captured_log {
	with_logging_spawn(sub {42}, {name => "TEST1"});
    };
    like($log, qr|executing TEST1|);
}

sub test_with_logging_spawn_can_log_command_line : Tests{
    my $log = with_captured_log {
	with_logging_spawn(
	    ['echo','foo','bar'],
	    {name => 'TEST3', log_command_line => 1})
    };
    like($log, qr|executing TEST3: \(echo foo bar\)|);
}

sub test_with_logging_spawn_redirects_stdout_and_stderr : Tests {
    my $log = with_captured_log {
	with_logging_spawn(
	    sub {
		print STDOUT "stdout\n";
		print STDERR "stderr\n";
	    },
	    {name => 'TEST2'})
    };
    like($log, qr|INFO: TEST2 STDOUT: stdout|);
    like($log, qr|INFO: TEST2 STDERR: stderr|);
}
