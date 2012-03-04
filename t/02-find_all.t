#!/usr/bin/env perl

use utf8;
use diagnostics;
use strict;
use warnings;
use Carp;
use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use KSM::Helper qw(:all);

########################################

sub test_croaks_when_no_list : Tests {
    eval { find_all(undef, sub { shift eq shift }) };
    like($@, qr|ought to be array reference|);

    eval { find_all("money", sub { shift eq shift }) };
    like($@, qr|ought to be array reference|);
}

sub test_croaks_when_no_function : Tests {
    eval { find_all([]) };
    like($@, qr|ought to be function|);

    eval { find_all(['money'], 'this is not a function') };
    like($@, qr|ought to be function|);
}

sub test_can_find_all_with_eq : Tests {
    is_deeply(find_all(['hello','world','!'], sub { shift eq 'world' }),
	      ['world']);
    is_deeply(find_all(['hello','world','!'], sub { shift eq 'frobo' }),
	      []);
}

sub test_works_with_arbitrary_functions : Tests {
    my $list = [{name => 'abe', age => 10},
                {name => 'barney', age => 20},
                {name => 'clide', age => 30},
                {name => 'dean', age => 40}];

    is_deeply(find_all($list, sub { shift->{name} eq 'clide' }),
	      [{name => 'clide', age => 30}]);

    is_deeply(find_all($list, sub { shift->{name} eq 'zoro' }),
	      []);
}

sub test_returns_all_elements_that_pass : Tests {
    my $list = [{name => 'abe', age => 10},
                {name => 'barney', age => 20},
                {name => 'clide', age => 30},
                {name => 'dean', age => 40}];
    is_deeply(find_all($list, sub { shift->{age} >= 30 }),
	      [{name => 'clide', age => 30},
	       {name => 'dean', age => 40}]);
}
