#!/usr/bin/env perl

use utf8;
use diagnostics;
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

sub with_captured_log {
    my ($function) = @_;

    with_temp(sub {
	my (undef,$logfile) = @_;
	KSM::Logger::initialize({level => KSM::Logger::DEBUG,
				 filename_template => $logfile,
				 reformatter => sub {
				     my ($level,$msg) = @_;
				     sprintf("%s: %s", $level, $msg);
				 }});
	eval {&{$function}(@_)};
	file_contents($logfile);
	      });
}

########################################
# with_logging_spawn

# sub test_should_verbose_name : Tests {
    my $log = with_captured_log(sub {
	with_logging_spawn(["echo","hello","world"], {
	    name => 'test echo',
			   });
				});
    like($log, qr|VERBOSE: test echo|);
# }

# sub test_should_debug_stdout : Tests {
    $log = with_captured_log(sub {
	with_logging_spawn(["echo","hello","world"], {
	    name => 'test echo',
			   });
				});
    like($log, qr|DEBUG: test echo: hello world|);
# }

# sub test_should_debug_stderr : Tests {
    $log = with_captured_log(sub {
	with_logging_spawn(["find","/root"], {
	    name => 'test find',
	    nonzero_okay => 1,
			   });
				});
    like($log, qr|DEBUG: test find: .*: Permission denied|);
# }

# sub test_should_error_stdout_when_status_not_zero : Tests {
    my $cwd = POSIX::getcwd;
    $log = with_captured_log(sub {
	eval {
	    with_logging_spawn(["find","/root",$cwd], {
		name => 'test find',
			       });
	};
				});
    like($log, qr|ERROR: test find: FAILED status 1|);
    like($log, qr|ERROR: test find: stdout: $cwd|);
# }

# sub test_should_error_stderr_when_status_not_zero : Tests {
    $cwd = POSIX::getcwd;
    $log = with_captured_log(sub {
	eval {
	    with_logging_spawn(["find","/root",$cwd], {
		name => 'test find',
			       });
	};
				});
    like($log, qr|ERROR: test find: .* Permission denied|);
# }

# sub test_should_log_other_programs_log_file_if_given : Tests {
    $cwd = POSIX::getcwd;
    $log = with_captured_log(sub {
	eval {
	    with_logging_spawn(["find","/root",$cwd], {
		name => 'test find',
		log => '/find/does/not/really/have/a.log',
			       });
	};
				});
    like($log, qr|consult its log file \[/find/does/not/really/have/a.log\]|);
# }

# sub test_should_die_when_status_not_zero : Tests {
    $cwd = POSIX::getcwd;
    $log = with_captured_log(sub {
	eval {
	    with_logging_spawn(["find","/root",$cwd], {
		name => 'test find',
			       });
	};
	like($@, qr|cannot test find: .* command = \[find /root .*\]|);
				});
# }

# sub test_should_return_child_hash : Tests {
    $log = with_captured_log(sub {
	my $child = with_logging_spawn(["echo","hello","world"], {
	    name => 'test echo',
				       });
	is($child->{stderr}, "");
	is($child->{stdout}, "hello world\n");
	is($child->{signal}, 0);
	is($child->{status}, 0);
	isnt($child->{ended}, undef);
	isnt($child->{started}, undef);
	is($child->{duration}, ($child->{ended} - $child->{started}));
				});
# }

# sub test_should_return_child_hash_nonzero_okay : Tests {
    $log = with_captured_log(sub {
	my $child = with_logging_spawn(["false"], {
	    name => 'test false',
	    nonzero_okay => 1,
				       });
	is($child->{stderr}, "");
	is($child->{stdout}, "");
	is($child->{signal}, 0);
	is($child->{status}, 1);
	isnt($child->{ended}, undef);
	isnt($child->{started}, undef);
	is($child->{duration}, ($child->{ended} - $child->{started}));
				});
# }

done_testing();
