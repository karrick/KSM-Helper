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
    eval { find('money', undef, sub { shift eq shift }) };
    like($@, qr|ought to be array reference|, "when list undef");

    eval { find('money', "money", sub { shift eq shift }) };
    like($@, qr|ought to be array reference|, "when list not ref to array");
}

sub test_croaks_when_no_function : Tests {
    eval { find('money', []) };
    like($@, qr/\bfunction\b/, "when function undef");

    eval { find('money', ['money'], 'money') };
    like($@, qr/\bfunction\b/, "when function not sub");
}

sub test_can_find_with_eq : Tests {
    is(find('world', ['hello','world','!'], sub { shift eq shift }), 'world');
    is(find('frobo', ['hello','world','!'], sub { shift eq shift }),
       undef);
}

sub test_works_with_arbitrary_functions : Tests {
    my $list = [{name => 'abe', age => 10},
                {name => 'barney', age => 20},
                {name => 'clide', age => 30},
                {name => 'dean', age => 40}];

    my $function = sub {
	my ($name,$person) = @_;
	($name eq $person->{name} ? 1 : 0);
    };

    is_deeply(find('clide', $list, $function),
	      {name => 'clide', age => 30});

    is_deeply(find('zoro', $list, $function),
	      undef);
}
