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

Version 0.04

=cut

our $VERSION = '0.04';


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
	all
	any
	change_account
	directory_contents
	ensure_directories_exist
        equals
        find
        shell_quote
	with_cwd
	with_locked_file
	with_timeout
)]);
our @EXPORT_OK = (@{$EXPORT_TAGS{'all'}});

=head1 SUBROUTINES/METHODS

=head2 all

Returns 1 if all elements in array satisfy test predicate.

Returns 0 if any element failed the predicate.

The test predicate function ought to take one value, the element to
test.

=cut

sub all {
    my ($list,$test) = @_;

    if(!defined($list) || ref($list) ne 'ARRAY') {
    	croak("first argument to find ought to be a list");
    } elsif(!defined($test) || ref($test) ne 'CODE') {
    	croak("second argument to find ought to be a function\n");
    } else {
	foreach (@$list) {
	    return 0 if(!&{$test}($_));
	}
	return 1;
    }
}

=head2 any

Returns 1 if any elements in array satisfy test predicate.

Returns 0 if all element failed the predicate.

The test predicate function ought to take one value, the element to
test.

=cut

sub any {
    my ($list,$test) = @_;

    if(!defined($list) || ref($list) ne 'ARRAY') {
    	croak("first argument to find ought to be a list");
    } elsif(!defined($test) || ref($test) ne 'CODE') {
    	croak("second argument to find ought to be a function\n");
    } else {
	foreach (@$list) {
	    return 1 if(&{$test}($_));
	}
	return 0;
    }
}

=head2 equals

Returns 1 value if first element equals the second element.

Attempts to perform a deep comparison by recursively calling itself.
This means, if your data structure contains a reference to itself, it
will pop your perl stack.

=cut

sub equals {
    my ($first,$second) = @_;

    if(defined($first)) {
	if(defined($second)) {
	    if(ref($first) eq ref($second)) {
		if(ref($first) eq '') {
		    no warnings 'numeric';
		    eval {return ($first == $second ? 1 : 0)};
		    eval {return ($first eq $second ? 1 : 0)};
		} else {
		    if(ref($first) eq 'ARRAY') {
			my $first_size = scalar(@$first);
			my $second_size = scalar(@$second);
			if($first_size == $second_size) {
			    my $size = scalar(@$first);
			    for(my $index = 0; $index < $size; $index++) {
				return 0 unless equals($first->[$index], $second->[$index]);
			    }
			    return 1;
			} else {
			    return 0;
			}
		    } elsif(ref($first) eq 'HASH') {
			my $first_keys = [keys %$first];
			my $second_keys = [keys %$second];
			if(scalar(@$first_keys) == scalar(@$second_keys)) {
			    $first_keys = [sort @$first_keys];
			    $second_keys = [sort @$second_keys];
			    if(equals($first_keys, $second_keys)) {
				my $values = [];
				foreach (@$first_keys) {
				    push(@$values, {first => $first->{$_}, second => $second->{$_}});
				}
				all($values, sub {
				    my ($pair) = @_;
				    equals($pair->{first}, $pair->{second});
				    });
			    } else {
				return 0;
			    }
			} else {
			    return 0;
			}
		    } elsif(ref($first) eq 'SCALAR') {
			equals($$first,$$second);
		    } elsif(ref($first) eq 'CODE') {
		    	equals(&$first,&$second);
		    } else {
			die sprintf("do not know how to compare [%s] references", ref($first));
		    }
		}
	    } else {
		return 0;
	    }
	} else {
	    return 0;
	}
    } elsif(defined($second)) {
	return 0;
    } else {
	return 1;
    }
}

=head2 find

Return the first element in the list for which the test predicate
returns a truthy value.

Returns undef when no element passes.

The test predicate function ought to take two values, the first is the
element to find, and the second is the element in the list being
tested.

    my $item = 'bozo';
    my $list = ['fred', 'jane', 'bozo', 'albert'];
    my $found = find($item, $list, \&equals);

=cut

sub find {
    my ($element,$list,$test) = @_;

    if(!defined($list) || ref($list) ne 'ARRAY') {
    	croak("second argument to find ought to be a list");
    } elsif(!defined($test) || ref($test) ne 'CODE') {
    	croak("third argument to find ought to be a function\n");
    } else {
	foreach (@$list) {
	    return $_ if(&{$test}($element, $_));
	}
    }
    undef;
}

=head2 directory_contents

Returns reference to array of strings, each string representing a file
system object inside directory argument.  Includes dot files, but
omits '.' and '..' from its response.

Croaks when directory argument is not a directory.

=cut

sub directory_contents {
    my ($dir) = @_;
    $dir ||= '.';
    if(! -d $dir) {
	croak sprintf("invalid directory: %s", $dir);
    } else {
	with_cwd($dir, 
		 sub {
		     [map { sprintf("%s/%s", $dir, $_) }
		      (glob(sprintf("*", $dir)),
		       grep(!/^\.{1,2}$/,
			    glob(sprintf(".*", $dir))))];
		 });
    }
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

=head2 change_account

Returns the command list, maybe prefixed by appropriate sudo and
arguments, to change the account.

=cut

sub change_account {
    my ($list,$account) = @_;
    if(defined($account) 
       && $account ne $ENV{LOGNAME}
       && $account ne '') {
	if($account eq 'root') {
	    unshift(@$list, '-n');
	    unshift(@$list, 'sudo');
	} else {
	    unshift(@$list, $account);
	    unshift(@$list, '-inu');
	    unshift(@$list, 'sudo');
	}
    }
    $list;
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
