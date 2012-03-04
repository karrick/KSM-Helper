#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use KSM::Helper 'with_temp';

########################################

sub test_croaks_when_missing_function : Tests {
    eval {with_temp()};
    like($@, qr/ought to be a function/);
}

sub test_passes_file_handle_and_filename_to_function : Tests {
    with_temp(
	sub {
	    my ($fh,$filename) = @_;
	    is(tell($fh), 0, "should pass file handle of temp to function");
	    ok(-e $filename, "should pass filename of temp to function");
	});
}

########################################

sub test_when_function_closes_file_handle : Tests {
    my ($result,$save_fh,$save_filename);
    eval {
	$result = with_temp(sub {
	    my ($fh,$filename) = @_;
	    $save_fh = $fh;
	    $save_filename = $filename;
	    close($fh);
	    "some value from function";
		  });
    };
    is($@, "");
    is($result, "some value from function");
    ok(! -e $save_filename, "should unlink file");
    {
	# expect &with_temp to close $fh, so disable expected warning
	no warnings;		
	is(tell($save_fh), -1, "should close file handle");
    }
}

sub test_when_function_unlinks_file : Tests {
    my ($result,$save_fh,$save_filename);
    eval {
	$result = with_temp(sub {
	    my ($fh,$filename) = @_;
	    $save_fh = $fh;
	    $save_filename = $filename;
	    unlink($filename);
	    "some value from function";
		  });
    };
    is($@, "");
    is($result, "some value from function");
    ok(! -e $save_filename, "should unlink file");
    {
	# expect &with_temp to close $fh, so disable expected warning
	no warnings;		
	is(tell($save_fh), -1, "should close file handle");
    }
}

sub test_when_function_closes_file_handle_and_unlinks_file : Tests {
    my ($result,$save_fh,$save_filename);
    eval {
	$result = with_temp(sub {
	    my ($fh,$filename) = @_;
	    $save_fh = $fh;
	    $save_filename = $filename;
	    close($fh);
	    unlink($filename);
	    "some value from function";
		  });
    };
    is($@, "");
    is($result, "some value from function");
    ok(! -e $save_filename, "should unlink file");
    {
	# expect &with_temp to close $fh, so disable expected warning
	no warnings;		
	is(tell($save_fh), -1, "should close file handle");
    }
}

########################################

sub test_when_function_croaks : Tests {
    my ($result,$save_fh,$save_filename);
    eval {
	$result = with_temp(sub {
	    my ($fh,$filename) = @_;
	    $save_fh = $fh;
	    $save_filename = $filename;
	    die("FORCED DIE FOR TESTING");
	    "some value from function should be ignored because of error";
		  });
    };
    like($@, qr|FORCED DIE FOR TESTING|);
    is($result, undef, "should not have returned value from function");
    ok(! -e $save_filename, "should unlink file");
    {
	# expect &with_temp to close $fh, so disable expected warning
	no warnings;		
	is(tell($save_fh), -1, "should close file handle");
    }
}
