#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Carp;
use Capture::Tiny qw(capture);
use File::Temp;
use Test::More;
use Test::Class;
use base qw(Test::Class);
END { Test::Class->runtests }

########################################

use KSM::Helper ':all';

########################################

sub test_returns_empty_array_if_empty_contents : Tests {
    my ($self) = @_;
    my $contents = "";
    is_deeply(split_lines_and_prune_comments($contents), []);
}

sub test_ignores_comment_lines : Tests {
    my ($self) = @_;
    my $contents = "";
    for(my $i = 1; $i <= 10 ; $i++) {
	$contents .= sprintf("#search%d.example.com synchronized       1347634816 G_361\n", $i);
    }
    is_deeply(split_lines_and_prune_comments($contents), []);
}

sub test_ignores_comments_at_end_of_lines : Tests {
    my ($self) = @_;
    my $contents = "";
    $contents .= "search1.example.com unsynchronized       1347634810 G_369 # foo\n";
    $contents .= "# this line should be ignored\n";
    $contents .= "search2.example.com synchronized       1347634816 G_361 # bar\n";
    $contents .= "\n";
    is_deeply(split_lines_and_prune_comments($contents),
	      [
	       "search1.example.com unsynchronized       1347634810 G_369 ",
	       "search2.example.com synchronized       1347634816 G_361 ",
	      ]);
}
