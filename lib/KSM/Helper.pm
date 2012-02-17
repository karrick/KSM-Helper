package KSM::Helper;

use warnings;
use strict;
use Carp;
use Fcntl qw(:flock);
use File::Path ();
use POSIX ();

=head1 NAME

KSM::Helper - The great new KSM::Helper!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use KSM::Helper;

    my $foo = KSM::Helper->new();
    ...

=head1 EXPORT

Although nothing is exported by default, the most common functions may
be included by importing the :all tag.  For example:

    use KSM::Helper qw(:all);

=cut

use Exporter qw(import);
our %EXPORT_TAGS = ( 'all' => [qw(
	with_cwd
	with_locked_file
	with_timeout
)]);
our @EXPORT_OK = (@{$EXPORT_TAGS{'all'}});

=head1 SUBROUTINES/METHODS

=head2 with_cwd

Change to the specified directory, creating it if necessary, and
execute the specified function.

Upon completion of the function, including errors, change back to the
original directory.

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

Execute the specified function with timeout protection.

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
