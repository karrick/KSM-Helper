#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use KSM::Helper qw(:all);

########################################

sub test_with_temp_croaks_when_missing_function : Tests {
    eval {with_temp()};
    like($@, qr/ought to be a function/);
}

sub test_with_temp_when_no_error : Tests {
    my $remember_temp;
    my $result = with_temp(sub {
	my ($temp) = @_;
	ok(-e $temp, sprintf("should pass temp file argument to function: %s", $temp));
	$remember_temp = $temp;
	42;
			   });
    is($result, 42, "should return the result of the function");
    ok(! -e $remember_temp, "should clean up temp file after function exists");
}

sub test_with_temp_when_error : Tests {
    my $remember_temp;
    my $result;

    eval {
	$result = with_temp(sub {
	    my ($temp) = @_;
	    $remember_temp = $temp;
	    die("FORCED DIE FOR TESTING");
	    42;
			    });
    };
    like($@, qr/FORCED DIE FOR TESTING/);
    is($result, undef, "should not return the result of the function");
    ok(! -e $remember_temp, "should clean up temp file after function exists");
}
