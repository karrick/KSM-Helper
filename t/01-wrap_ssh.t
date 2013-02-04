#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Carp;
use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use KSM::Helper ':all';

########################################

sub test_simple_same_host : Tests {
    chomp(my $hostname = `hostname -s`);
    is_deeply(wrap_ssh(['ping','foo']), ['ping','foo']);
    is_deeply(wrap_ssh(['ping','foo'], ''), ['ping','foo']);
    is_deeply(wrap_ssh(['ping','foo'], 'localhost'), ['ping','foo']);
    is_deeply(wrap_ssh(['ping','foo'], $hostname), ['ping','foo']);
}

sub test_other_host : Tests {
    is_deeply(wrap_ssh(['ping','foo'], 'elsewhere'),
	      ['ssh','elsewhere','-qxT','-o','PasswordAuthentication=no','-o','StrictHostKeyChecking=no','-o','ConnectTimeout=5','ping','foo']);
    is_deeply(wrap_ssh(['cat','silly name.txt'], 'elsewhere'),
	      ['ssh','elsewhere','-qxT','-o','PasswordAuthentication=no','-o','StrictHostKeyChecking=no','-o','ConnectTimeout=5','cat','silly\ name.txt']);
}
