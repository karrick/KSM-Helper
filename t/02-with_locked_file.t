#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use Fcntl qw(:flock);
use KSM::Helper qw(:all);

########################################

sub test_with_locked_file : Tests {
    my $file;

    $file = `mktemp`;
    chomp $file;

    is(with_locked_file($file,
			sub {
			    "lock obtained";
			}),
       "lock obtained");
    
    unlink($file) if -e $file;
}

sub test_with_locked_file_dies_if_unable_to_open : Tests {
    my $file;
    eval {
	$file = "/root/does/not/exist";
	chomp $file;
	eval {
	    with_locked_file($file,
			     sub {
				 1;
			     });
	};
	like($@, qr/^unable to open/);
    };
    
    unlink($file) if -e $file;
}

sub test_with_locked_file_dies_if_already_locked : Tests {
    my $file;
    eval {
	chomp($file = `mktemp`);
	open(FILE, '<', $file)
	    or fail sprintf('unable to open: [%s]: %s', $file, $!);
	flock(FILE, LOCK_EX | LOCK_NB)
	    or fail sprintf('unable to lock: [%s]: %s', $file, $!);
	eval {
	    with_locked_file($file,
			     sub {
				 1;
			     });
	};
	like($@, qr/^unable to lock/);
    };
    
    unlink($file) if -e $file;
}
