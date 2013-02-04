#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Carp;
use Capture::Tiny qw(capture);
use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use KSM::Helper qw(:all);

########################################

sub test_ought_file_handle_and_filename_to_function : Tests {
    with_temp {
	my ($fh,$filename) = @_;
	ok(defined(fileno($fh)));
	ok(-e $filename);
    };
}

sub test_function_closes_file_handle_after_done : Tests {
    my ($save_fh,$save_filename);
    with_temp {
	($save_fh, $save_filename) = @_;
    };
    ok(!defined(fileno($save_fh)), "ought to close file handle");
}

sub test_function_unlinks_temp_file_after_done : Tests {
    my ($save_fh,$save_filename);
    with_temp {
	($save_fh, $save_filename) = @_;
    };
    ok(! -e $save_filename, "ought to unlink file");
}

sub test_function_returns_result_after_done : Tests {
    my $result = with_temp {
	my ($fh, $filename) = @_;
	{ name => "foo", id => 42 };
    };
    is_deeply($result, { id => 42, name => "foo" });
}

sub test_cleans_up_if_function_dies : Tests {
    my ($result,$save_fh,$save_filename);
    eval {
	$result = with_temp {
	    ($save_fh, $save_filename) = @_;
	    die("FORCED DIE FOR TESTING");
	    "some value from function should be ignored because of error";
	};
    };
    like($@, qr|FORCED DIE FOR TESTING|);
    is($result, undef, "should not have returned value from function");
    ok(! -e $save_filename, "ought unlink file");
    ok(!defined(fileno($save_fh)), "ought close file handle");
}
