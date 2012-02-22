package KSM::Helper;

use utf8;
use warnings;
use strict;
use Carp;
use Fcntl qw(:flock);
use File::Basename ();
use File::Path ();
use POSIX ();

=head1 NAME

KSM::Helper - The great new KSM::Helper!

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

KSM::Helper provides a number of commonly used functions to expedite
writting your program.

Perhaps a little code snippet.

    use KSM::Helper qw(:all);

    with_cwd("/some/path", sub {
                             # do something with cwd
                           });
    ...

    with_locked_file("/some/file", 
                     sub {
                         # do something with that file
                     });
    ...

    with_timeout("timeout while calculating prime numbers",
                 60,
                 sub {
                     # what is the 1,000,000th prime number?
                 });

=head1 EXPORT

Although nothing is exported by default, the most common functions may
be included by importing the :all tag.  For example:

    use KSM::Helper qw(:all);

=cut

use Exporter qw(import);
our %EXPORT_TAGS = ( 'all' => [qw(
	change_account
	ensure_directories_exist
        shell_quote
	with_cwd
	with_locked_file
	with_timeout
)]);
our @EXPORT_OK = (@{$EXPORT_TAGS{'all'}});

=head1 SUBROUTINES/METHODS

=head2 with_cwd

Change to the specified directory, creating it if necessary, and
execute the specified function.

Even when an error is triggered in your function, the original working
directory is restored upon function exit.

=cut

sub with_cwd {
    my ($new_dir,$function) = @_;
    my $old_dir = POSIX::getcwd();
    my $change_back;
    if(!defined($new_dir) || $new_dir eq '') {
        croak('empty new_dir call to with_cwd()');
    }
    if(!$old_dir) {
        croak sprintf('$old_dir is empty when called with %s', $new_dir);
    }
    if($new_dir ne $old_dir) {
        File::Path::mkpath($new_dir);
        chdir($new_dir) or die($!);
        $change_back = 1;
    }
    my $result = eval { &{$function}(@_) };
    my $caught_error = $@;
    if($change_back) {
        chdir($old_dir) or die($!);
    }
    die($caught_error) if $caught_error;
    $result;
}

=head2 with_locked_file

Execute the specified function with a given file locked.

Lock file is created if it does not yet exist, but it is not removed
upon completion of function.

Even when an error is triggered in your function, the lock is removed
and the file handle is closed upon function exit.

This function will croak if another process has a lock on the
specified file.

=cut

sub with_locked_file {
    my ($file,$function) = @_;
    open(FILE, '<', $file) or croak sprintf('unable to open: [%s]: %s',$file, $!);
    flock(FILE, LOCK_EX | LOCK_NB) or croak sprintf('unable to lock: [%s]: %s',$file, $!);
    my $result = eval { &{$function}($file) };
    if($@) {
        close(FILE);
        die($@);
    }
    close(FILE);
    $result;
}

=head2 with_timeout

Executes the specified function, and terminate it early if the
function does not return within the specified number of seconds.

=cut

sub with_timeout {
    my ($emsg,$timeout,$function) = @_;
    my $result;

    local $SIG{ALRM} = sub {croak $emsg};
    alarm $timeout;
    $result = &{$function}();
    alarm 0;
    $result;
}

=head2 ensure_directories_exist

Takes and returns a filename, but creates the directory of the
filename if it does not exist if necessary.

It will croak if there are no permissions to create the required
directories.

=cut

sub ensure_directories_exist {
    my ($filename) = @_;
    # NOTE: mkpath croaks if error
    File::Path::mkpath(File::Basename::dirname($filename));
    $filename;
}

=head2 shell_quote

Returns the string quoted for the shell.

=cut

sub shell_quote {
    my ($input) = @_;
    if(defined($input)) {
	if($input eq '') {
	    "''";
	} else {
	    $input =~ s/([^-0-9a-zA-Z_.\/])/\\$1/g;
	    $input;
	}
    } else {
	'';
    }
}

=head2 change_account

Returns the string prefixed by sudo to change the account.

=cut

sub change_account {
    my ($input,$account) = @_;
    if(defined($account)) {
	if($account eq 'root') {
	    sprintf('sudo -n %s', $input);
	} elsif($account eq ''
		|| $account eq $ENV{LOGNAME}) {
	    $input;
	} else {
	    sprintf('sudo -inu %s %s',
		    $account, 
		    $input);
	}
    } else {
	$input;
    }
}

=head1 AUTHOR

Karrick S. McDermott, C<< <karrick at karrick.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ksm-helper at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=KSM-Helper>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc KSM::Helper


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=KSM-Helper>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/KSM-Helper>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/KSM-Helper>

=item * Search CPAN

L<http://search.cpan.org/dist/KSM-Helper/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Karrick S. McDermott.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of KSM::Helper
