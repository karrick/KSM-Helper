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

sub test_find_can_find_with_eq : Tests {
    is(KSM::Helper::find('world', ['hello','world','!'], sub { shift eq shift }), 'world');
    ok(!KSM::Helper::find('frobo', ['hello','world','!'], sub { shift eq shift }));
}

sub test_find_croaks_when_no_list : Tests {
    eval { KSM::Helper::find('money', undef, sub { shift eq shift }) };
    like($@, qr/\blist\b/, "when list undef");

    eval { KSM::Helper::find('money', "money", sub { shift eq shift }) };
    like($@, qr/\blist\b/, "when list not ref to array");
}

sub test_find_croaks_when_no_function : Tests {
    eval { KSM::Helper::find('money', []) };
    like($@, qr/\bfunction\b/, "when function undef");

    eval { KSM::Helper::find('money', ['money'], 'money') };
    like($@, qr/\bfunction\b/, "when function not sub");
}

sub test_find_works_with_equals_for_scalar : Tests {
    is(find('bozo',
	    ['fred', 'jane', 'bozo', 'albert'],
	    \&equals),
       'bozo');
}

sub test_find_works_with_equals_for_hash_ref : Tests {
    my $list = [{name => 'fred', age => 5},
		{name => 'jane', age => 13},
		{name => 'bozo', age => 47},
		{name => 'albert', age => 6}];

    is_deeply(find({name => 'bozo', age => 47}, $list, \&equals),
    	      {name => 'bozo', age => 47});

    is_deeply(find({name => 'bozo', age => 10}, $list, \&equals),
	      undef);
}
