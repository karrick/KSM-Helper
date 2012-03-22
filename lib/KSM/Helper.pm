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

Version 1.08

=cut

our $VERSION = '1.08';

=head1 SYNOPSIS

B<KSM::Helper> provides a number of commonly used functions to
expedite writting your program.

All library functions here use references to hashes and arrays instead
of a hash or array directly.

Code examples below assume the I<:all> export tag is imported by your
code, see the B<EXPORT> section for an example of how to do this.

=head1 EXPORT

Although no functions are exported by default, the most common
functions may be imported into your namespace by importing the :all
tag.  For example:

    C< use KSM::Helper qw(:all); >

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
	with_lock
	with_locked_file
	with_temp
	with_timeout
	with_timeout_spawn_child
	spawn
	spawn_bang
	wrap_ssh
	wrap_sudo
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

The I<predicate> function ought to take one value, the element to
test.

    C< if(all([2, 4, 6], sub { (shift % 2 == 0 ? 1 : 0) })) { >
    C<     print "all even\n"; >
    C< } >

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

The I<predicate> function ought to take one value, the element to
test.

    C< if(any([2, 4, 6], sub { (shift % 2 == 0 ? 1 : 0) })) { >
    C<   print "some even\n"; >
    C< } >

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

Returns 1 value if I<first> element equals the I<second> element, 0
otherwise.

Attempts to perform a deep comparison by recursively calling itself.
This means, if your data structure contains a reference to itself, it
will pop your Perl stack.

    C<< my $a = {"a" => ["q", {"b" => [0, 1]}], "c" => "bar"}; >>
    C<< my $b = {"a" => ["q", {"b" => [0, 1]}], "c" => "bar"}; >>
    C<< my $c = {"a" => ["q", {"b" => [2, 1]}], "c" => "bar"}; >>
    C<< my $d = {"a" => ["qr", {"b" => [0, 1]}], "c" => "bar"}; >>

    C<< print "a == b\n" if equals($a, $b); >>
    C<< print "a != c\n" unless equals($a, $c); >>

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
				if(!equals($first->[$index],$second->[$index])) {
				    return 0;
				}
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

Returns string containing contents of F<filename>.

    C<< my $some_data = file_contents($some_file); >>

=cut

sub file_contents {
    my ($filename) = @_;
    local $/;
    open(FH, '<', $filename)
	or croak sprintf("unable to open file %s: %s", $filename, $!);
    <FH>;
}

=head2 find

DEPRECATED -- Please consider using B<find_first>, for example:

   C<< my $found = find('clide', $list, >>
   C<<                  sub {  >>
   C<<                      my ($name,$person) = @_; >>
   C<<                      ($name eq $person->{name} ? 1 : 0); >>
   C<<                  }); >>

   ...can be converted to:

   C<< my $found = find_first($list, sub { shift->{name} eq 'clide' }); >>

Return the first element in I<list> for which the I<predicate>
function returns a truthy value.  Returns C<undef> when no element
passes.

The I<predicate> function ought to take two values, the first is the
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

Return the first element in I<list> for which the I<predicate>
function returns a truthy value.  Returns C<undef> when no element
passes.

The I<predicate> function ought to take a single value, namely, the
element in the list being tested.

    C<< my $list = [{name => 'abe', age => 10}, >>
    C<<             {name => 'barney', age => 20}, >>
    C<<             {name => 'clide', age => 30}, >>
    C<<             {name => 'dean', age => 40}]; >>
    C<< my $found = find_first($list, sub { shift->{name} eq 'clide' }); >>

    C<< if(defined($found)) { >>
    C<<     printf("Name: %s, Age: %d\n", $found->{name}, $found->{age}); >>
    C<< } >>

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

Return the list of elements in I<list> for which the I<predicate>
function returns a truthy value.  Returns empty list when no element
passes.

The I<predicate> function ought to take a single value, namely, the
element in the list being tested.

This function is a wrapper for the builtin B<grep> operator, but using
Array references instead of Arrays.  It also is has similar usage to
the B<find_first> function in this package, and this is primarily why
such a simple wrapper is included in this library.

    C<< my $list = [{name => 'abe', age => 10}, >>
    C<<             {name => 'barney', age => 20}, >>
    C<<             {name => 'clide', age => 30}, >>
    C<<             {name => 'dean', age => 40}]; >>
    C<< my $youngsters = find_all($list, sub { shift->{age} < 30 }); >>

    C<< foreach (@$found) { >>
    C<<     printf("Name: %s, Age: %d\n", $_->{name}, $_->{age}); >>
    C<< } >>

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
omits F<'.'> and F<'..'> from its response.

Croaks when directory argument is not a directory.

    C<< # Prints the contents of the $some_dir directory: >>
    C<< my $contents = directory_contents($some_dir); >>
    C<< foreach (@$contents) { >>
    C<<     printf("File: %s\n", $_); >>
    C<< } >>

    Prints the contents of I<$some_dir>, each with the directory name
    prefixed:

    C<< my $contents = [map { sprintf("%s/%s",$some_dir,$_) } >>
    C<<                 @{directory_contents($some_dir)}]; >>

    C<< foreach (@$contents) { >>
    C<<     printf("item: %s\n", $_); >>
    C<< } >>

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

Takes and returns I<filename>, but creates the directory of
I<filename> if it does not exist if necessary.

It will croak if permissions are inadequate to create the required
directories.

    C<< open(FH, '>', ensure_directories_exist($filename)) >>
    C<<     or croak sprintf("cannot open [%s]: %s", $!); >>

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

DEPRECATED -- see B<wrap_sudo>

Returns the command I<list>, maybe prefixed by appropriate C<sudo> and
arguments, to change the account.

If I<account> is undefined, the empty string, or matches the account
name of the process, this function acts as a no-op, and returns the
array reference unmodified.

Otherwise, it prefixes the command list with C<sudo> and arguments.

=cut

sub change_account {
    wrap_sudo(@_);
}

=head2 wrap_ssh

Internal function to prefix command I<list> with required B<ssh>
invocation parameters.

If I<host> is undefined, the empty string, or matches the hostname of
the server this process is running on, this function acts as a no-op,
and returns the array reference unmodified.

Otherwise, it prefixes command I<list> with B<ssh> and arguments.

=cut

sub wrap_ssh {
    my($list,$host)=@_;
    chomp(my $hostname = `hostname -s`);
    if(defined($host) && $host ne '' && $host ne 'localhost' && $host ne $hostname) {
	$list = [map { shell_quote($_) } @$list];
	unshift(@$list, ('ssh',$host,'-qxT','-o','PasswordAuthentication=no','-o','StrictHostKeyChecking=no','-o','ConnectTimeout=5'));
    }
    $list;
}

=head2 wrap_sudo

Internal function to prefix command I<list> with required B<sudo>
invocation parameters.

If I<account> is undefined, the empty string, or matches the account
name of the process, this function acts as a no-op, and returns the
array reference unmodified.

Otherwise, it prefixes command I<list> with B<sudo> and arguments.

=cut

sub wrap_sudo {
    my($list,$account)=@_;
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

Returns I<input> string quoted for the shell.

    C<< my $list = ['egrep','-i','ERROR|WARNING', 'crazy filename.txt']; >>
    C<< $list = [map { shell_quote($_) } @$list]; >>
    C<< system $list; >>

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

=head2 spawn

Function to fork/exec a child process.  Child process command line is
a I<list> of strings rather than a single string.  (See note regarding
parameter expansion.)

The result will be a hash with several key value pairs:

    C<< my $child = spawn(['echo','one','two']); >>

    C<< {signal => 0, status => 0, >>
    C<<  stdout => "one two\n", stderr => ""} >>

If you need to redirect C<stdin> from a string, pass it to this
function as part of the options hash.

    C<< my $child = spawn(['cat'], {stdin => "one\ntwo\tthree\n"}); >>

    C<< {signal => 0, status => 0, >>
    C<<  stdout => "one\ntwo\nthree\n", stderr => ""} >>

=head3 PARAMETER EXPANSION

As there will be no command interpreter, e.g., B<Bash>, to perform
parameter expansion for you.  In other words, the following will not
look for all the F<*.msg> files in the current working directory, but
instead look for I<the file> 'C<*.msg>', with an asterisk in its name.

    C<< my $child = spawn(['ls','*.msg']); >>

=cut

sub spawn {
    my($list,$options)=@_;
    croak("list must be array\n")   unless ref($list) eq 'ARRAY';
    if(defined($options) && ref($options) ne 'HASH') {
	croak("options must be hash");
    }
    my $child = {};
    my $result = with_standard_redirection({stdin => $options->{stdin}}, sub {
	my ($reaped_children,$exit_requested) = ({});
	local $SIG{INT} = local $SIG{TERM} = sub {$exit_requested = 1};
	local $SIG{CHLD} = sub {
	    use POSIX ":sys_wait_h";
	    while ((my $pid = waitpid(-1,WNOHANG)) > 0) {
		my $status = $?;
		$reaped_children->{$pid} = {ended => time, status => $status};
	    }
	};

	if($child->{pid} = fork) {
	    $child->{started} = time;
	    $child->{ended} = $child->{started} + $options->{timeout} if(defined($options->{timeout}));
	    while(!defined($reaped_children->{$child->{pid}})) {
		my $slept = (defined($options->{timeout}) ? sleep($child->{ended} - $child->{started}) : sleep);
		if(!defined($reaped_children->{$child->{pid}})) {
		    if($exit_requested) {
			kill('TERM',$child->{pid});
		    } elsif(defined($child->{ended}) && time >= $child->{ended}) {
			kill('TERM',$child->{pid});
		    }
		}
	    }
	    # merge reaped_children values back into child hash
	    $child->{status} = $reaped_children->{$child->{pid}}->{status};
	    $child->{ended} = $reaped_children->{$child->{pid}}->{ended};
	    $child->{duration} = $child->{ended} - $child->{started};
	    exit if($exit_requested);
	} elsif(defined($child->{pid})) {
	    $SIG{TERM} = $SIG{INT} = 'DEFAULT';
	    $list = wrap_sudo($list,$options->{sudo});
	    $list = wrap_ssh($list,$options->{host});
	    exit 1 if(!exec @$list);
	    # NOTREACHED
	} else {
	    die sprintf("unable to fork: %s", $!);
	}
					   });
    # merge pertinent result hash values into child
    $child->{signal} = $child->{status} & 127;
    $child->{status} = $child->{status} >> 8;
    $child->{stderr} = $result->{stderr};
    $child->{stdout} = $result->{stdout};

    # NOTE: value and exception are returned by
    # with_standard_redirection, but they are not expected for spawn's
    # function
    if(0) {
	$child->{exception} = $result->{exception};
	$child->{value} = $result->{value};
    }
    $child;
}

=head2 spawn_bang

When you want to spawn a subprocess, and you'd like to have an
exception raised for you when the process exits with a non-zero status
code, B<spawn_bang> might be useful.

    C<< spawn_bang(['scp',"${host}:${source}",$dest]); >>
    C<< print "$source downloaded if we get here\n"; >>

=cut

sub spawn_bang {
    my($list,$options)=@_;
    croak("list must be array\n")   unless ref($list) eq 'ARRAY';
    if(defined($options) && ref($options) ne 'HASH') {
	croak("options must be hash");
    }
    my $child = spawn($list,$options);
    if($child->{exception}) {
	die($child->{exception});
    } elsif($child->{status}) {
	die sprintf("child (%s) status %d", (defined($options->{name}) ? $options->{name} : "unknown"), $child->{status});
    }
    $child;
}

=head2 with_logging_spawn

Execute I<list>, routing C<STDOUT> and C<STDERR> to log facility.

=cut

sub with_logging_spawn {
    my ($list,$options) = @_;
    croak("ought to pass in list\n") if(ref($list) ne 'ARRAY');
    croak("options ought to be hash\n") if(ref($options) ne 'HASH');
    croak("options ought to have name key\n") if(!defined($options->{name}));
    croak("option logger ought to be CODE\n") if(defined($options->{logger}) && ref($options->{logger}) ne 'CODE');

    my $logger = $options->{logger} || \&KSM::Logger::verbose;
    my $joined = join(' ',@$list);

    if($options->{log_command_line}) {
	&{$logger}("%s: [%s]", $options->{name}, $joined);
    } else {
	&{$logger}("%s", $options->{name});
    }

    my $child = spawn($list, $options);
    if($child->{status} == 0 || $options->{nonzero_okay}) {
	foreach my $stream (qw(stdout stderr)) {
	    foreach (split(/\n/, $child->{$stream})) {debug("%s: %s", $options->{name}, $_)}
	}
    } else {
	foreach my $stream (qw(stdout stderr)) {
	    foreach (split(/\n/, $child->{$stream})) {error("%s: %s", $options->{name}, $_)}
	}
	die error("unable to %s: (exit code: %d) command = [%s]\n",
		  $options->{name}, $child->{status}, $joined);
    }
    $child;
}

=head2 with_cwd

Change current working directory to I<directory>, creating it if
necessary, and execute I<function>.

Even when an error is triggered in I<function>, the original working
directory is restored upon function exit.  If the original working
directory no longer exists when I<function> exits, this will croak
with a suitable message.

    C<< with_cwd("/some/path", >>
    C<<          sub { >>
    C<<              # do something with cwd >>
    C<<          }); >>

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

=head2 with_lock

Execute I<function> with F<filename> locked.

F<filename> is created if it does not yet exist, but it is not removed
upon completion of I<function>.

Even when an error is triggered in I<function>, the lock is removed
and the file handle is closed upon I<function> exit.

This function will croak if another process has a lock on F<filename>.

    C<< with_lock("/some/file",  >>
    C<<           sub { >>
    C<<               # do something with that file >>
    C<<           }); >>

=cut

sub with_lock {
    my ($filename,$function) = @_;
    my ($result,$status);
    if(ref($function) ne 'CODE') {
	croak("argument ought to be function");
    }
    verbose("getting exclusive lock: [%s]", $filename);
    open(FILE, '<', $filename) or croak error('unable to open: [%s]: %s',$filename, $!);
    flock(FILE, LOCK_EX | LOCK_NB) or croak error('unable to lock: [%s]: %s',$filename, $!);
    verbose("have exclusive lock: [%s]", $filename);
    $result = eval { &{$function}() };
    $status = $@;
    close(FILE) or croak error("unable to close: [%s]: %s",$filename, $!);
    verbose("released exclusive lock: [%s]", $filename);
    croak($status) if($status);
    $result;
}

=head2 with_locked_file

DEPRECATED -- see B<with_lock>.

=cut

sub with_locked_file {
    with_lock(@_);
}

=head2 with_standard_redirection

Execute I<function> with C<stdin> redirected from a source string, and
C<stdout>, and C<stderr> redirected to strings.

If you need to redirect C<stdin> from a string, pass it as part of the
I<options> hash:

    C<< my $result = with_standard_redirection({stdin => "foobar\n"}, >>
    C<<                  sub {  >>
    C<<                      while(<>) { print; } >>
    C<<                      42; >>
    C<<                  }); >>

The I<result> hash will contain several key value pairs. The above
command would return the following hash:

    C<< { stdout => "foobar\n", stderr => "", >>
    C<<   value => 42, exception => "" } >>

The exception key value pair will contain any message from an enclosed
die:

    C<< my $result = with_standard_redirection({stdin => "foobar\n"}, >>
    C<<                  sub {  >>
    C<<                      while(<>) { print; } >>
    C<<                      die "unloved"; >>
    C<<                  }); >>
    C<< die($result->{exception}) if($result->{exception}); >>

=cut

sub with_standard_redirection {
    my ($options,$function) = @_;
    croak("options must be hash")  unless ref($options) eq 'HASH';
    croak("function must be code") unless ref($function) eq 'CODE';

    my $result = {};
    open(my $stdin_saved, "<&STDIN")   or die "unable to dup STDIN";
    open(my $stdout_saved, ">&STDOUT") or die "unable to dup STDOUT";
    open(my $stderr_saved, ">&STDERR") or die "unable to dup STDERR";
    with_temp(
	sub {
	    my ($stdin_fh, $stdin_temp) = @_;
	    if(defined($options->{stdin})) {
		open(FH,'>',$stdin_temp)
		    or die sprintf("unable to open > [%s]: %s", $stdin_temp, $!);
		printf FH "%s", $options->{stdin};
		close FH;
		open(STDIN,"<&",$stdin_fh)
		    or die sprintf("unable to redirect STDIN: %s", $!);
	    }
	    with_temp(
		sub {
		    my ($stderr_fh, $stderr_temp) = @_;
		    open(STDERR,">&",$stderr_fh)
			or die sprintf("unable to reopen STDERR: %s", $!);
		    select((select(STDERR), $| = 1)[0]); # autoflush
		    with_temp(
			sub {
			    my ($stdout_fh, $stdout_temp) = @_;
			    open(STDOUT,">&",$stdout_fh)
				or die sprintf("unable to reopen STDOUT: %s", $!);
			    select((select(STDOUT), $| = 1)[0]); # autoflush
			    $result->{value} = eval { &{$function}() };
			    $result->{exception} = $@;
			    $result->{stdout} = file_contents($stdout_temp);
			});
		    $result->{stderr} = file_contents($stderr_temp);
		});
	});
    open(STDIN, "<&", $stdin_saved)   or die "unable to restore STDIN";
    open(STDOUT, ">&", $stdout_saved) or die "unable to restore STDOUT";
    open(STDERR, ">&", $stderr_saved) or die "unable to restore STDERR";
    $result;
}

=head2 with_temp

Executes I<function> with a temporary file, cleaning it up upon
completion of I<function>.

Returns both the opened file handle and the file name.  It is
recommended that software is written to only use the file handle, as
this prevents some types of race conditions that could be leveraged by
mischiefous programs.  The file name is also provided.

    C<< my $filename = "data.txt"; >>
    C<< with_temp(sub { >>
    C<<               my ($fh,$fname) = @_; >>
    C<<               printf $fh "some test data\n"; >>
    C<<               close $fh; >>
    C<<               rename($fname,$filename); >>
    C<<           }); >>

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

Executes I<function>, and terminate it early if it does not return
within I<timeout> number of seconds.

    C<< with_timeout("calculating primes", 10, >>
    C<<              sub { >>
    C<<                # convert electrical energy into heat energy >>
    C<<              }); >>

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

DEPRECATED -- see B<spawn>

Spawns I<child> process, optionally with a I<timeout>.

    C<< with_timeout_spawn_child({ >>
    C<<     name => "timeout while calculating prime numbers", >>
    C<<     timeout => 60, >>
    C<<     function => sub { >>
    C<<         # what is the 1,000,000th prime number? >>
    C<<     }); >>

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

Internal function to act as the process' handler for C<SIGCHLD>
signals to prevent zombie processes by collecting child exit status
information when a child process terminates.

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

Internal function to send child process the C<TERM> signal.

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

Internal function to collect stats from terminated child process.

=cut

sub collect_child_stats {
    my ($child, $reaped_child) = @_;

    $child->{status} = $reaped_child->{status};
    $child->{ended} = $reaped_child->{ended};
    $child->{duration} = ($child->{ended} - $child->{started});
    $child;
}

=head2 log_child_termination

Internal function to log the termination of a child process.

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

Please report any bugs or feature requests to C<bug-ksm-helper at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=KSM-Helper>.  I will
be notified, and then you'll automatically be notified of progress on
your bug as I make changes.




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
