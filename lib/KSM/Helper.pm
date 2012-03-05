package KSM::Helper;

use utf8;
use strict;
use warnings;

use Capture::Tiny qw(capture);
use Carp;
use Fcntl qw(:flock);
use File::Basename ();
use File::Path ();
use File::Temp ();
use POSIX qw(:sys_wait_h);

use KSM::Logger qw(:all);

=head1 NAME

KSM::Helper - The great new KSM::Helper!

=head1 VERSION

Version 1.02

=cut

our $VERSION = '1.02';

=head1 SYNOPSIS

KSM::Helper provides a number of commonly used functions to expedite
writting your program.

All library functions here use references to hashes and arrays instead
of a hash or array directly.

Code examples below assume the :all export tag is imported by your
code, see the EXPORT section for an example of how to do this.

=head1 EXPORT

Although no functions are exported by default, the most common
functions may be imported into your namespace by importing the :all
tag.  For example:

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
	file_contents
	find
	find_all
	find_first
	shell_quote
	with_cwd
	with_locked_file
	with_temp
	with_timeout
	with_timeout_spawn_child
)]);
our @EXPORT_OK = (@{$EXPORT_TAGS{'all'}});

=head2 GLOBALS

Various global variables required to manage child processes.

=cut

our $reaped_children = {};
our $exit_requested;

=head1 SUBROUTINES/METHODS

=head2 all

Returns 1 if all elements in array satisfy test predicate, 0
otherwise.

The test predicate function ought to take one value, the element to
test.

    print "all even\n" if(all([2, 4, 6], sub { (shift % 2 == 0 ? 1 : 0) }));

=cut

sub all {
    my ($list,$predicate) = @_;
    if(ref($list) ne 'ARRAY') {
    	croak("argument ought to be array reference");
    } elsif(ref($predicate) ne 'CODE') {
    	croak("argument ought to be function");
    } else {
	foreach (@$list) {
	    return 0 if(!&{$predicate}($_));
	}
	return 1;
    }
}

=head2 any

Returns 1 if any elements in array satisfy test predicate, 0
otherwise.

The test predicate function ought to take one value, the element to
test.

    print "some even\n" if(any([2, 4, 6], sub { (shift % 2 == 0 ? 1 : 0) }));

=cut

sub any {
    my ($list,$predicate) = @_;
    if(ref($list) ne 'ARRAY') {
    	croak("argument ought to be array reference");
    } elsif(ref($predicate) ne 'CODE') {
    	croak("argument ought to be function");
    } else {
    	foreach (@$list) {
    	    return 1 if(&{$predicate}($_));
    	}
    	return 0;
    }
}

=head2 equals

Returns 1 value if first element equals the second element, 0
otherwise.

Attempts to perform a deep comparison by recursively calling itself.
This means, if your data structure contains a reference to itself, it
will pop your Perl stack.

    my $a = {"a" => ["q", {"b" => [0, 1]}], "c" => "bar"};
    my $b = {"a" => ["q", {"b" => [0, 1]}], "c" => "bar"};
    my $c = {"a" => ["q", {"b" => [2, 1]}], "c" => "bar"};
    my $d = {"a" => ["qr", {"b" => [0, 1]}], "c" => "bar"};

    print "a == b\n" if equals($a, $b);
    print "a != c\n" unless equals($a, $c);

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

=head2 file_contents

Returns string containing contents of a file.

    my $some_data = file_contents($some_file);

=cut

sub file_contents {
    my ($filename) = @_;
    local $/;
    open(FH, '<', $filename)
	or croak sprintf("unable to open file %s: %s", $filename, $!);
    <FH>;
}

=head2 find

DEPRECATED -- Please consider using &find_first, for example:

   my $found = find('clide', $list,
                    sub { 
                        my ($name,$person) = @_;
                        ($name eq $person->{name} ? 1 : 0);
                    });

   ...can be converted to:

   my $found = find_first($list, sub { shift->{name} eq 'clide' });

Return the first element in the list for which the test predicate
returns a truthy value.  Returns undef when no element passes.

The test predicate function ought to take two values, the first is the
element to find, and the second is the element in the list being
tested.

=cut

sub find {
    my ($element,$list,$predicate) = @_;
    if(ref($list) ne 'ARRAY') {
    	croak("argument ought to be array reference");
    } elsif(ref($predicate) ne 'CODE') {
    	croak("argument ought to be function");
    } else {
    	foreach (@$list) {
    	    return $_ if(&{$predicate}($element, $_));
    	}
	undef;
    }
}

=head2 find_first

Return the first element in the list for which the test predicate
returns a truthy value.  Returns undef when no element passes.

The test predicate function ought to take a single value, namely, the
element in the list being tested.

    my $list = [{name => 'abe', age => 10},
                {name => 'barney', age => 20},
                {name => 'clide', age => 30},
                {name => 'dean', age => 40}];
    my $found = find_first($list, sub { shift->{name} eq 'clide' });
    if(defined($found)) {
        printf("Name: %s, Age: %d\n", $found->{name}, $found->{age});
    }

=cut

sub find_first {
    my ($list,$predicate) = @_;
    if(ref($list) ne 'ARRAY') {
    	croak("argument ought to be array reference");
    } elsif(ref($predicate) ne 'CODE') {
    	croak("argument ought to be function");
    } else {
    	foreach (@$list) {
    	    return $_ if(&{$predicate}($_));
    	}
	undef;
    }
}

=head2 find_all

Return the list of elements in the list for which the test predicate
returns a truthy value.  Returns empty list when no element passes.

The test predicate function ought to take a single value, namely, the
element in the list being tested.

This function is a wrapper for grep, but using Array references
instead of Arrays.  It also is has similar usage to the &find_first
function in this package, and this is primarily why such a simple
wrapper is included in this library.

    my $list = [{name => 'abe', age => 10},
                {name => 'barney', age => 20},
                {name => 'clide', age => 30},
                {name => 'dean', age => 40}];
    my $youngsters = find_all($list, sub { shift->{age} < 30 });
    foreach (@$found) {
        printf("Name: %s, Age: %d\n", $_->{name}, $_->{age});
    }

=cut

sub find_all {
    my ($list,$predicate) = @_;
    if(ref($list) ne 'ARRAY') {
    	croak("argument ought to be array reference");
    } elsif(ref($predicate) ne 'CODE') {
    	croak("argument ought to be function");
    } else {
	[grep { &{$predicate}($_) } @$list];
    }
}

=head2 directory_contents

Returns reference to array of strings, each string representing a file
system object inside directory argument.  Includes dot files, but
omits '.' and '..' from its response.

Croaks when directory argument is not a directory.

    # Prints the contents of the $some_dir directory:
    my $contents = directory_contents($some_dir);
    foreach (@$contents) {
        printf("File: %s\n", $_);
    }

    # Prints the contents of the $some_dir directory, each with the
    # directory name prefixed:
    my $contents = [map { sprintf("%s/%s",$some_dir,$_) } @{directory_contents($some_dir)}];
    foreach (@$contents) {
        printf("File: %s\n", $_);
    }

=cut

sub directory_contents {
    my ($dir) = @_;
    $dir ||= '.';
    my $files = [];
    eval {
	opendir(DH, $dir) or die("cannot opendir: $!");
	foreach (readdir DH) {
	    push(@$files,$_) unless /^\.{1,2}$/;
	}
	closedir DH;
    };
    croak("unable to read directory_contents [$dir]: $!") if($@);
    $files;
}

=head2 ensure_directories_exist

Takes and returns a filename, but creates the directory of the
filename if it does not exist if necessary.

It will croak if there are no permissions to create the required
directories.

    open(FH, '>', ensure_directories_exist($filename))
        or croak sprintf("cannot open [%s]: %s", $!);

=cut

sub ensure_directories_exist {
    my ($filename) = @_;
    eval {
	# NOTE: mkpath croaks if error
	File::Path::mkpath(File::Basename::dirname($filename));
    };
    if($@) {
	croak sprintf("unable to ensure_directories_exist for [%s]: %s",
		      $filename, $@);
    }
    $filename;
}

=head2 change_account

Returns the command list, maybe prefixed by appropriate sudo and
arguments, to change the account.

If the account is undefined, the empty string, or matches the account
name of the process, this function acts as a no-op, and returns the
array reference unmodified.

Otherwise, it prefixes the command list with the sudo and arguments to
sudo.

=cut

sub change_account {
    my ($list,$account) = @_;
    if(defined($account) 
       && $account ne $ENV{LOGNAME}
       && $account ne '') {
	if($account eq 'root') {
	    unshift(@$list, ('sudo','-n'));
	} else {
	    unshift(@$list, ('sudo','-inu',$account));
	}
    }
    $list;
}

=head2 shell_quote

Returns the string quoted for the shell.

    my $list = ['egrep','-i','ERROR|WARNING', 'crazy filename.txt'];
    $list = [map { shell_quote($_) } @$list];
    system $list;

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
directory is restored upon function exit.  If the original working
directory no longer exists when your function exits, this will croak
with a suitable message.

    with_cwd("/some/path",
             sub {
                 # do something with cwd
             });

=cut

sub with_cwd {
    my ($new_dir,$function) = @_;
    my ($result,$status);
    my $old_dir = POSIX::getcwd();
    if(ref($function) ne 'CODE') {
	croak("argument ought to be function");
    }
    eval {
    chdir($new_dir) 
	or croak warning("unable to change directory [%s]: %s", $new_dir, $!);
    };
    if($@) {
	my $status = $@;
	if($status =~ /No such file or directory/) {
	    File::Path::mkpath($new_dir);	    
	    chdir($new_dir) 
		or croak warning("unable to change directory [%s]: %s", $new_dir, $!);
	} else {
	    croak $status;
	}
    }
    verbose("cwd: [%s]", $new_dir);
    $result = eval { &{$function}() };
    $status = $@;
    chdir($old_dir) 
	or croak error("unable to return to previous directory [%s]: %s",
		       $old_dir, $!);
    verbose("cwd: [%s]", $old_dir);
    croak($status) if $status;
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

    with_locked_file("/some/file", 
                     sub {
                         # do something with that file
                     });

=cut

sub with_locked_file {
    my ($file,$function) = @_;
    my ($result,$status);
    if(ref($function) ne 'CODE') {
	croak("argument ought to be function");
    }
    verbose("getting exclusive lock: [%s]", $file);
    open(FILE, '<', $file) or croak error('unable to open: [%s]: %s',$file, $!);
    flock(FILE, LOCK_EX | LOCK_NB) or croak error('unable to lock: [%s]: %s',$file, $!);
    verbose("have exclusive lock: [%s]", $file);
    $result = eval { &{$function}() };
    $status = $@;
    close(FILE) or croak error("unable to close: [%s]: %s",$file, $!);
    verbose("released exclusive lock: [%s]", $file);
    croak($status) if($status);
    $result;
}

=head2 with_temp

Executes the specified function with a temporary file, cleaning it up
upon completion of function.

Returns both the opened file handle and the file name.  It is
recommended that software is written to only use the file handle, as
this prevents some types of race conditions that could be leveraged by
mischiefous programs.  The file name is also provided.

    my $filename = "data.txt";
    with_temp(sub {
                  my ($fh,$fname) = @_;
                  printf $fh "some test data\n";
                  close $fh;
                  rename($fname,$filename);
              });

=cut

sub with_temp {
    my ($function) = @_;
    my ($result,$status);
    if(ref($function) ne 'CODE') {
    	croak("argument ought to be function");
    }
    my ($fh,$fname) = File::Temp::tempfile();
    $result = eval {&{$function}($fh,$fname)};
    $status = $@;
    {
	# localize no warnings
	no warnings;
	close($fh) if(tell($fh) != -1);
    }
    unlink($fname);
    croak($status) if($status);
    $result;
}

=head2 with_timeout

Executes the specified function, and terminate it early if the
function does not return within the specified number of seconds.

    with_timeout("calculating primes", 10,
                 sub {
                   # convert electrical energy into heat energy
                 });

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

=head2 with_timeout_spawn_child

Spawns a child and executes the specified function, optionally with a
timeout.

    with_timeout_spawn_child({
        name => "timeout while calculating prime numbers",
        timeout => 60,
        function => sub {
            # what is the 1,000,000th prime number?
        });

=cut

sub with_timeout_spawn_child {
    my ($child) = @_;

    # croak if required arguments missing or invalid
    if(ref($child) ne 'HASH') {
	croak("nothing to execute");
    } elsif(!defined($child->{name}) || !$child->{name}) {
	croak("nothing to execute: missing name");
    } elsif(ref($child->{list}) ne 'ARRAY' && ref($child->{function}) ne 'CODE') {
	croak("nothing to execute: missing list");
    }

    # ??? Does this corrupt signal handler from caller? neither using
    # local nor saving and restoring works for this.
    $SIG{CHLD} = \&REAPER;

    my $result = eval {
	foreach my $signal (qw(INT TERM)) {
	    $SIG{$signal} = sub { info("received %s signal; preparing to exit", $signal); $exit_requested = 1 };
	}

	if(my $pid = fork) {
	    $child->{pid} = $pid;
	    $child->{started} = POSIX::strftime("%s", gmtime);
	    if(defined($child->{timeout})) {
		$child->{ended} = $child->{started} + $child->{timeout};
	    }
	    info('spawned child %d (%s)%s', $pid, $child->{name},
		 (defined($child->{timeout}) 
		  ? sprintf(" with %d second timeout", $child->{timeout})
		  : ""));
	    while(!defined($reaped_children->{$pid})) {
		my $slept = (defined($child->{timeout})
			     ? sleep($child->{ended} - $child->{started})
			     : sleep);
		debug("parent slept for %d seconds", $slept);
		if(!defined($reaped_children->{$pid})) {
		    if($exit_requested) {
			info("sending child %d (%s) the TERM signal", $child->{pid}, $child->{name});
			kill('TERM', $child->{pid});
		    } elsif(defined($child->{ended}) && POSIX::strftime("%s", gmtime) > $child->{ended}) {
			timeout_child($child);
		    }
		}
	    }
	    log_child_termination(collect_child_stats($child, delete($reaped_children->{$pid})));
	    if($exit_requested) {
		info("all children terminated: exiting.");
		exit;
	    }
	    # TODO: determine how to handle non-zero exit of child (die or
	    # simply return child hash with status?)
	    $child;
	} elsif(defined($pid)) {
	    $SIG{TERM} = $SIG{INT} = 'DEFAULT';
	    if($child->{function}) {
		$0 = $child->{name};
		eval {&{$child->{function}}()};
		if($@) {
		    error("%s", $@);
		    exit -1;
		}
		exit;
	    } elsif($child->{list}) {
		if(!exec @{$child->{list}}) {
		    error("unable to exec (%s): (%s): %s", 
			  $child->{name}, $child->{list}->[0], $!);
		    exit 1;
		}
	    }
	} else {
	    die error("unable to fork: %s", $!);
	}
    };
    $result;
}

=head2 REAPER

Acts as the process' handler for SIGCHLD signals to prevent zombie
processes by collecting child exit status information when a child
process terminates.

=cut

sub REAPER {
    my ($pid,$status);
    # If a second child dies while in the signal handler caused by the
    # first death, we won't get another signal. So must loop here else
    # we will leave the unreaped child as a zombie. And the next time
    # two children die we get another zombie. And so on.
    while (($pid = waitpid(-1,WNOHANG)) > 0) {
	$status = $?;
	$reaped_children->{$pid} = {
	    ended => POSIX::strftime("%s", gmtime),
	    status => $status,
	};
    }
    $SIG{CHLD} = \&REAPER;  # still loathe SysV
}

=head2 timeout_child

Log and send child process the TERM signal.

=cut

sub timeout_child {
    my ($child) = @_;
    info("timeout: sending child %d (%s) the TERM signal%s",
	 $child->{pid}, $child->{name},
	 (defined($child->{timeout}) 
	  ? sprintf(" after %s seconds", $child->{timeout}) 
	  : ''));
    kill('TERM', $child->{pid});
}

=head2 collect_child_stats

Collect stats from terminated child process.

=cut

sub collect_child_stats {
    my ($child, $reaped_child) = @_;

    $child->{status} = $reaped_child->{status};
    $child->{ended} = $reaped_child->{ended};
    $child->{duration} = ($child->{ended} - $child->{started});
    $child;
}

=head2 log_child_termination

Logs the termination of a child process.

=cut

sub log_child_termination {
    my ($child) = @_;

    croak("invalid child") unless defined($child);
    croak("invalid child") unless ref($child) eq 'HASH';
    croak("invalid child pid") unless defined($child->{pid});
    croak sprintf("invalid child duration for %d", $child->{pid}) unless defined($child->{duration});
    croak sprintf("invalid child name for %d", $child->{pid}) unless defined($child->{name});
    croak sprintf("invalid child status for %d", $child->{pid}) unless defined($child->{status});

    my $child_status = $child->{status};
    if($child_status) {
	if($child_status & 127) {
	    warning('child %d (%s) received signal %d and terminated status code %d',
		    $child->{pid}, $child->{name},
		    $child_status & 127, $child_status >> 8);
	} else {
	    warning('child %d (%s) terminated status code %d',
		    $child->{pid}, $child->{name},
		    $child_status >> 8);
	}
    } else {
	info('child %d (%s) terminated status code 0',
	     $child->{pid}, $child->{name});
    }
    $child;
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
