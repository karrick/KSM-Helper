#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'KSM::Helper' ) || print "Bail out!
";
}

diag( "Testing KSM::Helper $KSM::Helper::VERSION, Perl $], $^X" );
