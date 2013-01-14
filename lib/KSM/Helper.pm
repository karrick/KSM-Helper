package KSM::Helper;

use utf8;
use strict;
use warnings;

use Carp;
use Fcntl qw(:flock);
use File::Basename ();
use File::Path ();
use File::Temp ();
use POSIX qw(:sys_wait_h);

use KSM::Logger qw(:all);

use constant BUFSIZ => 4096;

=head1 NAME

KSM::Helper - The great new KSM::Helper!

=head1 VERSION

Version 2.0.2

=cut

our $VERSION = '2.0.2';

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
	equals
	find_all
	find_first

	command_loop

	create_required_parent_directories
	directory_contents
	ensure_directory_exists
	for_each_non_dotted_item_in_directory

	file_read
	file_write

	reset_signal_handlers
	shell_quote
	spawn
	spawn_bang
	sysread_spooler
	with_capture_spawn
	with_logging_spawn
	wrap_ssh
	wrap_sudo

	split_lines_and_prune_comments
	strip

	with_cwd
	with_lock
	with_temp

)]);
our @EXPORT_OK = (@{$EXPORT_TAGS{'all'}});

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
			croak sprintf("do not know how to compare [%s] references\n", ref($first));
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

=head2 command_loop

Read from filehandle I<fh>, and invoke I<stdout_handler> for each
newline terminated string. While processing, invoke I<timeout_handler>
if no input for I<timeout> seconds.

If an error occurs, logs any errors and dies with an appropriate error
message.

=cut

sub command_loop {
    my ($fh,$stdout_handler,$timeout_handler,$timeout) = @_;

    if(ref($stdout_handler ne 'CODE')) {
	croak("stdout_handler not a function");
    } elsif(ref($timeout_handler ne 'CODE')) {
	croak("timeout_handler not a function");
    }

    my ($rin,$stdout_buf) = ("","");
    my $fd = fileno($fh);
    vec($rin, $fd, 1) = 1;

    while(1) {
	my $nfound = select(my $rout=$rin, undef, undef, $timeout);
	if($nfound == -1) {
	    die sprintf("cannot select: [%s]\n", $!);
	} elsif($nfound > 0) {
	    if(vec($rout, $fd, 1) == 1) {
		eval {
		    $stdout_buf = sysread_spooler($fh, $stdout_buf, $stdout_handler);
		};
		if(my $status = $@) {
		    chomp($status);
		    last if($status eq 'eof');
		}
	    }
	} else {
	    $timeout_handler->();
	}
    }
}

=head2 create_required_parent_directories

Create any parent directories required for file.

=cut

sub create_required_parent_directories {
    my ($filename) = @_;
    ensure_directory_exists(File::Basename::dirname($filename));
    $filename;
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
	opendir(DH, $dir) or die sprintf("cannot opendir: [%s]\n", $!);
	foreach (readdir DH) {
	    push(@$files, $_) unless /^\.{1,2}$/; # ??? maybe change
	}
	closedir(DH);
    };
    if(my $status = $@) {
	chomp($status);
	die sprintf("cannot read directory_contents (%s): [%s]\n", $dir, $status);
    }
    $files;
}

=head2 ensure_directory_exists

Takes and returns I<dirname>, but creates all required parent
directories of I<dirname> in addition to I<dirname> if any do not
already exist.

It will croak if permissions are inadequate to create the required
directories.

    C<< opendir(DH, ensure_directory_exists($queue)) >>
    C<<     or croak sprintf("cannot opendir (%s): [%s]\n", $!); >>

=cut

sub ensure_directory_exists {
    my ($dirname) = @_;
    eval {
	File::Path::mkpath($dirname); # NOTE: mkpath croaks if error
    };
    if(my $status = $@) {
	chomp($status);
	die sprintf("cannot ensure_directory_exists (%s): [%s]\n", $dirname, $status);
    }
    $dirname;
}

=head2 for_each_non_dotted_item_in_directory

For each non-dotted item in I<directory>, execute I<fn> with the
pathname of the child as the argument.

=cut

sub for_each_non_dotted_item_in_directory {
    my ($directory,$fn) = @_;

    eval {
	opendir(DH, $directory)
	    or die sprintf("cannot opendir (%s): [%s]\n", $directory, $!);
	while(my $child = readdir(DH)) {
	    next if $child =~ /^\./;
	    eval {
		$fn->(sprintf("%s/%s", $directory, $child));
	    };
	    if(my $status = $@) {
		chomp($status);
		warning("cannot process child: [%s]\n", $status);
	    }
	}
	closedir(DH);
    };
    if(my $status = $@) {
	chomp($status);
	die sprintf("cannot: [%s]\n", $status);
    }
}

=head2 file_read

Returns string containing contents of F<filename>.

    C<< my $some_data = file_read($some_file); >>

Opens and reads the file assuming UTF-8 content.

=cut

sub file_read {
    my ($filename) = @_;
    local $/;
    open(FH, '<:encoding(UTF-8)', $filename)
	or die sprintf("cannot open file (%s): [%s]\n", $filename, $!);
    # flock(FH, LOCK_SH)
    #	or die sprintf("cannot lock (%s): [%s]\n", $filename, $!);
    my $contents = <FH>;
    close(FH);
    $contents;
}

=head2 file_write

Returns string containing contents of F<filename>.

    C<< file_write($some_file,$blob); >>

Opens and writes the file assuming UTF-8 content. Value of function is
the value of the data written.

=cut

sub file_write {
    my ($filename,$blob) = @_;
    my $dirname = File::Basename::dirname($filename);
    my $basename = File::Basename::basename($filename);
    my $tempname = sprintf("%s/.%s", $dirname, $basename);

    eval {
	create_required_parent_directories($tempname);
	open(FH, '>:encoding(UTF-8)', $tempname)
	    or die sprintf("cannot open file (%s): [%s]\n", $tempname, $!);
	flock(FH, LOCK_EX)
	    or die sprintf("cannot lock (%s): [%s]\n", $tempname, $!);
	print FH $blob;
	close(FH);
	rename($tempname, $filename)
	    or die sprintf("cannot rename file (%s) -> (%s): [%s]\n", $tempname, $filename, $!);
    };
    my $status = $@;
    close(FH);
    if($status) {
	chomp($status);
	die sprintf("cannot write file (%s): [%s]\n", $tempname, $status);
    }
    $blob;
}

=head2 reset_signal_handlers

Resets all signal handlers to their default handlers.

Used by newly spawned child processes.

=cut

sub reset_signal_handlers {
    foreach (qw(HUP INT QUIT ILL ABRT FPE SEGV PIPE ALRM TERM USR1 USR2 CHLD CONT STOP TSTP TTIN TTOU)) {
	$SIG{$_} = 'DEFAULT';
    }
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

Function to execute a child process, either a command line or perl
function.

If executing a function, set first parameter to the desired code
reference:

    C<< my $result = spawn(sub { print "hello\n"; });

If executing a different program, set the first parameter to the
desired array of strings for the command:

    C<< my $result = spawn(['echo','foo','bar']);

If you desire a timeout, specify such:

    C<< my $result = spawn(['sleep','60'], {timeout => 1});

If you desire execution of the other program as a different user,
ensure your program has the ability to run 'sudo', and specify the
alternate user:

    C<< my $result = spawn(['/home/user2/bin/foo'], {user => 'user2'});

If you desire execution of a program on a different host, ensure your
program has the ability to execute 'ssh' using ssh-keys, and specify
the alternate host:

    C<< my $result = spawn(['hostname'], {host => 'host2'});

The I<user> and I<host> options are only used in conjunction with
execution of a command line program. This function will croak if you
set either I<user> or I<host> option when the first parameter is a
code reference.

The result will be a hash with several key value pairs:

    C<< my $child = spawn(['echo','one','two']); >>

    C<< {signal => 0, status => 0, >>
    C<<  started => X, ended => Y, duration => Z } >>

=head3 PARAMETER EXPANSION

There will be no command interpreter, e.g., B<Bash>, to perform
parameter expansion for you. In other words, the following will not
look for all the F<*.msg> files in the current working directory, but
instead look for I<the file> 'C<*.msg>', with an asterisk in its name.

    C<< my $child = spawn(['ls','*.msg']); >>

=cut

sub spawn {
    my ($execute,$options) = @_;

    if(ref($execute) eq 'ARRAY') {
	$execute = wrap_sudo($execute, $options->{user});
	$execute = wrap_ssh($execute,  $options->{host});
    } elsif(ref($execute) eq 'CODE') {
	croak("cannot change host without a command line list\n") if($options->{host});
	croak("cannot change user without a command line list\n") if($options->{user});
    } else {
	croak("nothing to execute: no function or list\n");
    }

    my ($reaped_children,$exit_requested) = ({});
    my $child = { pid => undef, started => time(), duration => undef, ended => undef, status => undef };
    if(defined($options->{timeout})) {
	$child->{ended} = $child->{started} + $options->{timeout};
    }

    local $SIG{CHLD} = sub { 
	local $!;
	while ((my $pid = waitpid(-1, WNOHANG)) > 0) {
	    my $status = $?;
	    $reaped_children->{$pid} = {ended => time(), 
					status => ($status >> 8), 
					signal => ($status & 127)};
	}
    };

    my ($stdout_fh_read,$stdout_fh_write);
    pipe($stdout_fh_read, $stdout_fh_write) or die sprintf("cannot pipe: [%s]\n", $!);
    $stdout_fh_write->autoflush(1);
    my ($stderr_fh_read,$stderr_fh_write);
    pipe($stderr_fh_read, $stderr_fh_write) or die sprintf("cannot pipe: [%s]\n", $!);
    $stderr_fh_write->autoflush(1);

    if($child->{pid} = fork()) {
	eval {
	    my $status;
	    local $SIG{INT} = local $SIG{TERM} = sub {$exit_requested = 1};
	    my ($rin,$stdout_buf,$stderr_buf) = ("","","");
	    my $stdout_handler = $options->{stdout_handler} || sub { print STDOUT shift };
	    my $stderr_handler = $options->{stderr_handler} || sub { print STDERR shift };
	    my $stdout_fd = fileno($stdout_fh_read);
	    my $stderr_fd = fileno($stderr_fh_read);
	    vec($rin, $stdout_fd, 1) = 1;
	    vec($rin, $stderr_fd, 1) = 1;
	    close($stdout_fh_write) or die sprintf("cannot close: [%s]\n", $!);
	    close($stderr_fh_write) or die sprintf("cannot close: [%s]\n", $!);

	    while(!defined($reaped_children->{$child->{pid}})) {
		eval {
		    my $timeout = (defined($options->{timeout}) ? ($child->{ended} - time()) : undef);
		    my $nfound = select(my $rout=$rin, undef, undef, $timeout);
		    if($nfound == -1) {
			die sprintf("cannot select: [%s]\n", $!);
		    } elsif($nfound > 0) {
			if(vec($rout, $stdout_fd, 1) == 1) {
			    $stdout_buf = sysread_spooler($stdout_fh_read, $stdout_buf, $stdout_handler);
			}
			if(vec($rout, $stderr_fd, 1) == 1) {
			    $stderr_buf = sysread_spooler($stderr_fh_read, $stderr_buf, $stderr_handler);
			}
		    } elsif($exit_requested ||
			    ((!defined($reaped_children->{$child->{pid}}))
			     && (defined($child->{ended}) && time() >= $child->{ended}))) {
			kill('TERM', $child->{pid});
		    }
		};
		if($@) {
		    $status = $@;
		    kill('TERM', $child->{pid}); # parent error: term child
		}
	    }
	    exit if($exit_requested);
	    if($status) {
		chomp($status);
		die sprintf("%s\n", $status) if($status ne 'eof');
	    }
	    close($stdout_fh_read) or die sprintf("cannot close: [%s]\n", $!);
	    close($stderr_fh_read) or die sprintf("cannot close: [%s]\n", $!);
	    # merge reaped_children values back into child hash
	    $child->{status} = $reaped_children->{$child->{pid}}->{status};
	    $child->{signal} = $reaped_children->{$child->{pid}}->{signal};
	    $child->{ended}  = $reaped_children->{$child->{pid}}->{ended};
	    $child->{duration} = ($child->{ended} - $child->{started});
	};
	if(my $status = $@) {
	    chomp($status);
	    die sprintf("PARENT FAILURE: %s\n", $status);
	}
    } elsif(defined($child->{pid})) {
	eval {
	    reset_signal_handlers();
	    $0 = $options->{name} if($options->{name});

	    close($stdout_fh_read) or die sprintf("cannot close STDOUT: [%s]\n", $!);
	    close($stderr_fh_read) or die sprintf("cannot close STDERR: [%s]\n", $!);
	    open(STDOUT, '>&=', $stdout_fh_write) or die error("cannot redirect STDOUT: [%s]\n", $!);
	    open(STDERR, '>&=', $stderr_fh_write) or die error("cannot redirect STDERR: [%s]\n", $!);

	    if(ref($execute) eq 'CODE') {
		$execute->();
		exit;
	    } elsif(ref($execute) eq 'ARRAY') {
		if(!exec {$execute->[0]} @$execute) {
		    die sprintf("cannot exec: ", $!);
		}
	    }
	    die "NOTREACHED";
	};
	if(my $status = $@) {
	    chomp($status);
	    printf STDERR "CHILD FAILURE: %s\n", $status;
	    exit(1);
	}
    } else {
	die sprintf("cannot fork: [%s]\n", $!);
    }
    $child;
}

=head2 spawn_bang

Invoke I<execute>. If the exit code is non-zero and I<nonzero_okay> is
not true, die with appropriate error message.

=cut

sub spawn_bang {
    my ($execute,$options) = @_;
    my $child = spawn($execute, $options);
    if($child->{status} != 0 && !$options->{nonzero_okay}) {
	my ($command,$why) = ("","");
	if(ref($execute) eq 'ARRAY') {
	    $command = sprintf(": (%s)", join(" ", @$execute)) 
	}
	if($options->{log}) {
	    $why = sprintf(": To find out why, please consult its log file [%s]", $options->{log});
	}

	die sprintf("cannot %s: (exit code: %d)%s%s", $options->{name}, $child->{status}, $command, $why);
    }
    $child;
}

=head2 sysread_spooler

Read from I<fh> using B<sysread> subroutine, chunking into lines,
submitting each line to I<handler>. Prior to chunking, prepend
I<buffer> to the contents of what is read. Return all data after the
last newline.

=cut

sub sysread_spooler {
    my ($fh, $buffer, $handler) = @_;
    my ($si,$buf,$line) = (0);
    my $count = sysread($fh, $buf, BUFSIZ);
    if(!defined($count)) {
	die sprintf("cannot sysread: [%s]\n", $!);
    } elsif($count > 0) {
	$buffer .= $buf;
	while((my $ei = index($buffer, "\n", $si)) >= 0) {
	    $line = substr($buffer, $si, (1 + $ei - $si));
	    $handler->($line);
	    $si = (1 + $ei);
	}
    } else {
	# $handler->($buffer) if($buffer);
    	die("eof\n");
    }
    substr($buffer, $si);
}

=head2 with_capture_spawn

Spawn a child process with standard output and standard error
captured.

=cut

sub with_capture_spawn {
    my ($execute,$options) = @_;
    my ($stdout,$stderr) = ("","");
    $options->{stdout_handler} = sub { $stdout .= shift };
    $options->{stderr_handler} = sub { $stderr .= shift };
    my $child = spawn($execute, $options);
    $child->{stdout} = $stdout;
    $child->{stderr} = $stderr;
    $child;
}

=head2 with_logging_spawn

Invoke I<execute>, routing C<STDOUT> and C<STDERR> to log facility.

=cut

sub with_logging_spawn {
    my ($execute,$options) = @_;

    croak("cannot execute: missing name\n") if(!$options->{name});
    my $name = $options->{name};
    $options->{stderr_handler} = sub {warning("%s: %s\n", $name, shift)};
    $options->{stdout_handler} = sub {info("%s: %s\n", $name, shift)};

    my $command = "";
    if($options->{log_command_line} && ref($execute) eq 'ARRAY') {
	$command = sprintf(": (%s)", join(" ", @$execute));
    }

    info("executing %s%s\n", $name, $command);
    spawn_bang($execute, $options);
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

=cut

sub wrap_sudo {
    my($list,$account)=@_;
    unshift(@$list, ('sudo','-Hnu',$account)) if($account);
    $list;
}

=head2 split_lines_and_prune_comments

Split content string into array of lines, and strip off comments and
eliminate empty lines.

=cut

sub split_lines_and_prune_comments {
    my ($contents) = @_;
    find_all([map { my ($data,$comment) = split(/#/); $data; } split(/\n/, $contents)],
             sub { $_ });
}

=head2 strip

Library function to strip leading and trailing whitespace from a string.

Returns undef when passed undefined value.

=cut

sub strip {
    my ($string) = @_;
    if(defined($string)) {
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
    }
    return $string;
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
            or die warning("cannot change directory (%s): [%s]\n", $new_dir, $!);
    };
    if(my $status = $@) {
	chomp($status);
	if($status =~ /No such file or directory/) {
	    File::Path::mkpath($new_dir);
	    chdir($new_dir)
		or die warning("cannot change directory (%s): [%s]\n", $new_dir, $!);
	} else {
	    die sprintf("%s\n", $status);
	}
    }
    verbose("cwd: [%s]", $new_dir);
    $result = eval {$function->()};
    chomp($status = $@);
    chdir($old_dir)
	or die error("cannot return to previous directory [%s]: %s\n",
		       $old_dir, $!);
    verbose("cwd: [%s]", $old_dir);
    die sprintf("%s\n", $status) if $status;
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
    croak("argument ought to be function") if(ref($function) ne 'CODE');
    verbose("getting exclusive lock: [%s]", $filename);
    open(FILE, '<:encoding(UTF-8)', $filename) or croak error("cannot open (%s): [%s]\n", $filename, $!);
    flock(FILE, LOCK_EX | LOCK_NB) or croak error("cannot lock (%s): [%s]\n", $filename, $!);
    verbose("have exclusive lock: [%s]", $filename);
    $result = eval {$function->()};
    chomp($status = $@);
    close(FILE) or die error("cannot close (%s): [%s]\n", $filename, $!);
    verbose("released exclusive lock: [%s]", $filename);
    die sprintf("%s\n", $status) if($status);
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
    my ($result);
    croak("argument ought to be function") if(ref($function) ne 'CODE');
    my ($fh,$fname) = File::Temp::tempfile();
    $result = eval {$function->($fh,$fname)};
    chomp(my $status = $@);
    {
	# localize no warnings
	no warnings;
	close($fh) if(tell($fh) != -1);
    }
    unlink($fname);
    die sprintf("%s\n", $status) if($status);
    $result;
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
