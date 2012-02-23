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
# is_numeric

# sub test_is_numeric : Tests {
#     ok(KSM::Helper::is_numeric(0), "should be true when 0");
#     # ok(KSM::Helper::is_numeric(-1), "should be true when -1");
# }

########################################
# equals

sub test_equals_compares_undef : Tests {
    is(equals, 1);
    is(equals(), 1);
    is(equals(undef,undef), 1);
}

sub test_equals_compares_scalar : Tests {
    is(equals(1), 0);
    is(equals(undef,1), 0);

    is(equals(1,1), 1, "should be 1 when equals(1,1)");
    is(equals(1,2), 0, "should be 0 when equals(1,2)");
    is(equals(1,'foo'), 0, "should be 0 when equals(1,'foo')");

    is(equals('foo','foo'), 1, "should be 1 when equals('foo','foo')");
    is(equals('foo','bar'), 0, "should be 0 when equals('foo','bar')");
}

sub test_equals_compares_references : Tests {
    is(equals(1, [1]), 0, "should be 0 when equals(1, [1])");
    is(equals([1], 1), 0, "should be 0 when equals([1], 1)");
    is(equals([1], [1]), 1, "should be 1 when equals([1], [1])");
}

sub test_equals_compares_arrays : Tests {
    is(equals([1], []), 0, "should be 0 when equals([1],[])");
    is(equals([], [1]), 0, "should be 0 when equals([],[1])");

    is(equals([], []), 1, "should be 1 when equals([],[])");
    is(equals([1], [1]), 1, "should be 1 when equals([1],[1])");
    is(equals(['foo'], ['foo']), 1, "should be 1 when equals(['foo'],['foo'])");
    is(equals(['foo',1], ['foo',1]), 1, "should be 1 when equals(['foo',1],['foo',1])");
    is(equals(['foo',1], [1,'foo']), 0, "should be 0 when equals(['foo',1],[1, 'foo'])");
}

sub test_equals_compares_hashes : Tests {
    is(equals({},{}), 1, "should be 1 when equals({},{})");
    is(equals({a => 1},{a => 1}), 1, "should be 1 when equals({a => 1},{a => 1})");
    is(equals({a => 1, b => 2},{a => 1, b => 2}), 1, "should be 1 when equals({a => 1, b => 2},{a => 1, b => 2})");

    is(equals({a => 1},{b => 1}), 0, "should be 0 when equals({a => 1},{b => 1})");
    is(equals({a => 1},{a => 2}), 0, "should be 0 when equals({a => 1},{a => 2})");

    is(equals({a => 1},{}), 0, "should be 1 when equals({a => 1},{})");

    is(equals({name => 'bozo', age => 10}, {name => 'bozo', age => 10}), 1, "should be 1 when complex hash match");
    is(equals({age => 10, name => 'bozo'}, {name => 'bozo', age => 10}), 1, "should be 1 when complex hash have keys in different order");

    is(equals({name => 'bozo', age => 10}, {name => 'bozo', age => 47}), 0, "should be 0 when complex hashes do not match");
}

sub test_equals_compares_references_of_scalars : Tests {
    is(equals(\10,\10), 1, "should be 1 when equals(\10,\10)");
    is(equals(\10,\5), 0, "should be 0 when equals(\10,\5)");
}

sub test_equals_compares_references_of_code : Tests {
    my $function = sub {1};
    is(equals($function, $function), 1, 'should be 1 when equals($function,$function');
    is(equals(sub { 2 }, sub { 2 }), 1, 'should be 1 when equals(sub { 2 }, sub { 2 }');
    is(equals(sub { 3 }, sub { 4 }), 0, 'should be 0 when equals(sub { 3 }, sub { 4 }');
}

sub test_equals_compares_arrays_of_mixed_types : Tests {
    my $a = {"a" => ["q", {"b" => [0, 1]}], "c" => "bar"};
    my $b = {"a" => ["q", {"b" => [0, 1]}], "c" => "bar"};
    my $c = {"a" => ["q", {"b" => [2, 1]}], "c" => "bar"};
    my $d = {"a" => ["qr", {"b" => [0, 1]}], "c" => "bar"};

    is(equals($a, $b), 1, 'should be 1 when equals($a, $b)');
    is(equals($a, $c), 0, 'should be 0 when equals($a, $c)');
    is(equals($a, $d), 0, 'should be 0 when equals($a, $d)');
}
