#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use CGI;
use Capture::Tiny qw(capture);
use DBI;
use File::Temp qw(tempfile);
use KSM::Helper qw(:all);
use KSM::Logger qw(:all);
use Test::Class;
use Test::MockObject::Extends;
use Test::MockObject;
use Test::More;
use base qw(Test::Class);

END { Test::Class->runtests }

########################################

BEGIN {
    Test::MockObject::Extends->new()->fake_module(
    	'GIS::CoordinateSearch',
    	'get_coordinates_perl' => sub {
    	    my ($content) = @_;
    	    [{
    		lat => 52,
    		long => 79,
    		match => "content",
    		country   => "DS",
    		confidence => 100,
    	     }];
    	});
    Test::MockObject::Extends->new()->fake_module(
    	'GazetteerGateway',
    	'extract_coordinates_from_document' => sub {
    	    my ($content, $options) = @_;
    	    [{
    		lat => 42,
    		long => 69,
    		match => "okay",
    		country   => "DS",
    		confidence => 66,
    	     },
	     {
		 lat => 52,
		 long => 79,
		 match => "content",
		 country   => "DS",
		 confidence => 100,
    	     }];
    	});
};
use GeoExtractor qw(:test);

########################################
# logger

sub initialize_logger : Test(startup) {
    my ($self) = @_;
    ($self->{log_fh},$self->{log}) = tempfile();
    KSM::Logger::initialize({level => KSM::Logger::DEBUG,
			     filename_template => $self->{log},
			     reformatter => sub {
				 sprintf("%s: %s", @_);
			     }});
}

sub truncate_log : Test(setup) {
    my ($self) = @_;
    truncate($self->{log_fh}, 0);
}

sub cleanup_logger : Test(shutdown) {
    my ($self) = @_;
    unlink $self->{log};
}

########################################
# initializers

sub connect_and_prepare_database : Test(startup) {
    my ($self) = @_;

    my $database = 'test_database';
    my $hostname = 'localhost';
    $self->{db} = { 
	datasource => sprintf("dbi:Pg:database=%s;host=%s", $database, $hostname),
	username => 'postgres',
	attr => {AutoCommit => 0},
	prepare => \&prepare_database_statements,
	reconnect => 1,
    };
    $self->{database_user_postgres} = DBI->connect(sprintf("dbi:Pg:database=%s;host=%s", $database, $hostname), 'postgres', '');
}

sub reset_database : Test(setup) {
    my ($self) = @_;
    $self->{database_user_postgres}->do("delete from feeds");
}

########################################
# helpers

sub with_nothing_out(&) {
    my ($code) = @_;
    my ($stdout,$stderr,$result) = capture {
	$code->();
    };
    is($stdout, "");
    is($stderr, "");
    $result;
}

sub insert_feeds {
    my ($database,$name,$attribute,$archive,$state) = @_;
    $database->{handle}->do("insert into feeds (name,attribute,archive,state) values (?,?,?,?)", {}, $name,$attribute,$archive,$state);
}

########################################

sub test_with_database_invokes_prepare_step_if_given : Tests {
    my ($self) = @_;

    my $db = $self->{db};
    my $invoked = 0;
    $db->{prepare} = sub { $invoked = 1 };
    with_nothing_out {
	with_database($db,
		      sub {
			  my ($database) = @_;
		      });
    };
    is($invoked, 1);
}

sub test_with_database_invokes_error_automatically : Tests {
    my ($self) = @_;

    my $db = $self->{db};

    $db->{prepare} = sub { 
	my ($database) = @_;
	$database->{get_feed_info} = $database->{handle}->prepare(q{SELECT foo,name,archive FROM (SELECT name, regexp_split_to_table(attribute, e'\\\s+') AS attribute, state, archive FROM feeds) AS attribute WHERE state = 'active' AND attribute = 'gis' ORDER BY name});
	$database->{get_feed_info}->execute();
	die "should have died already";
    };
    $db->{reconnect} = 0;

    with_nothing_out {
	eval {
	    with_database($db,
			  sub {
			      my ($database) = @_;
			  });
	};
	my $status = $@;
	unlike($status, qr|should have died already|);
	like($status, qr|column "foo" does not exist|);
    };
    my $log = file_read($self->{log});
    like($log, qr|invoking prepare function|);
    unlike($log, qr|returning from prepare function|);
}

sub test_with_database_returns_last_value : Tests {
    my ($self) = @_;

    with_nothing_out {
	is(with_database($self->{db},
			 sub {
			     my ($database) = @_;
			     insert_feeds($database, "silly", "gis", "/home/archive/silly", "state");
			     42;
			 }), 
	   42);
    };
    like(file_read($self->{log}), qr|attempting to initialize connection to database|);
}

sub test_with_database_does_not_reconnect_unless_told : Tests {
    my ($self) = @_;

    my $run_once = 1;
    my $step = 0;

    my $db = $self->{db};
    $db->{reconnect} = 0;

    with_nothing_out {
	eval {
	    with_database($db,
			 sub {
			     my ($database) = @_;
			     insert_feeds($database, "feed1", "gis", "/home/archive/feed1", "state");

			     if($run_once) {
				 $step += 1;
				 $run_once = 0;
				 $database->{handle}->disconnect();
			     }

			     $step += 1;
			     insert_feeds($database, "feed2", "gis", "/home/archive/feed2", "state");

			     $step += 1;
			  });
	};
	like($@, qr|database|);
    };
    is($run_once, 0);
    is($step, 2);
    unlike(file_read($self->{log}), qr|error with database connection|);
    unlike(file_read($self->{log}), qr|sleep for \d+|);
    like(file_read($self->{log}), qr|disconnected database|);
}

sub test_with_database_reconnects_when_required : Tests {
    my ($self) = @_;

    my $run_once = 1;
    my $step = 0;

    my $db = $self->{db};
    $db->{reconnect} = 1;

    with_nothing_out {
	with_database($db,
		      sub {
			  my ($database) = @_;
			  insert_feeds($database, "feed1", "gis", "/home/archive/feed1", "state");

			  if($run_once) {
			      $step += 1;
			      $run_once = 0;
			      diag "disconnecting from database... expect sleep during test";
			      $database->{handle}->disconnect();
			  }

			  $step += 1;
			  insert_feeds($database, "feed2", "gis", "/home/archive/feed2", "state");

			  $step += 1;
		      });
    };
    is($run_once, 0);
    is($step, 4);
    like(file_read($self->{log}), qr|error with database connection|);
    like(file_read($self->{log}), qr|sleep for \d+|);
}
