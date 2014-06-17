use strict;
use warnings;

our ($irc, $my_name);

# Load the channel ops file:
open my $fh, '<', 'pdl-channel-ops.txt';
my %ops;
while(my $line = <$fh>) {
	chomp $line;
	$ops{$line}++;
}
close $fh;

# Sub to write the verifications file out to disk:
sub write_out {
	open $fh, '>', 'pdl-channel-ops.txt';
	foreach my $nick (keys %ops) {
		print $fh "$nick\n";
	}
	close $fh;
}

sub private_message {
	my $nick = shift;
	for my $line (@_) {
		$irc->yield(privmsg => $nick, $line);
	}
}

# Find the pdl documentation
use PDL::Doc;
my ($d,$f);
my $pdldoc;
DIRECTORY: for $d (@INC) {
	$f = $d."/PDL/pdldoc.db";
	if (-f $f) {
		print "Found docs database $f\n";
		$pdldoc = new PDL::Doc ($f);
		last DIRECTORY;
	}
}

############# Delayed message handling #############
my %messages;
if (-f 'piddlebot-messages.txt') {
	open my $in_fh, '<', 'piddlebot-messages.txt';
	while(my $line = <$in_fh>) {
		chomp $line;
		$line =~ /^(\w+): (.*)/ or next;
		$messages{$1} = $2;
	}
	unlink 'piddlebot-messages.txt';
}
END {
	# Store the messages when this script terminates
	open my $out_fh, '>', 'piddlebot-messages.txt';
	while (my ($nick, $message) = each %messages) {
		print $out_fh "$nick: $message\n";
	}
	close $out_fh;
}

############# Doers #############

sub do_public_response {
	my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
	my $nick    = (split /!/, $who)[0];
	log_it("<$nick> $msg\n");
	
	# Construct hyperlink if cpan is requested:
	if ($msg =~ /^cpan (.+)/) {
		say_it("http://p3rl.org/$1");
	}
	# Construct a link to the docs on the web site:
	elsif ($msg =~ /^help (.+)/) {
		my $to_find = $1;
		(my $location = $to_find) =~ s{::}{/}g;
		say_it("$nick: http://pdl.perl.org/?docs=$location&title=PDL::$to_find");
	}
	elsif ($msg =~ /^paste/) {
		say_it("$nick: http://scsys.co.uk:8001/");
	}
	elsif ($msg =~ /^liddle_piddle_bot.+?trust (\S+)/) {
		my $to_op = $1;
		chomp $to_op;
		if ($ops{$nick}) {
			# Op the person:
			$irc->yield(mode => '#pdl +o', $to_op);
			
			# Add the ident as a trusted nick
			$ops{$to_op}++;
			write_out();
			
			# Send the new user their temporary password:
			private_message($to_op
				, "Welcome, $to_op, to the inner sanctum. To learn more about what this means, please read"
				, "https://github.com/PDLPorters/pdl/wiki/PDL-IRC"
			);
			
		}
		else {
			say_it("Silly $nick: only trusted users can tell me to trust someone");
		}
	}
	elsif ($msg =~ /^whereis (.*)/) {
		my $command = $1;
		my $where_is = '';
		my @matches = $pdldoc->search(qr/(PDL::)?$command$/, ['Name']);
		if (@matches) {
			$where_is = "Found $command in ";
			my @modules;
			foreach my $match (@matches) {
				(undef, my $hash) = @$match;
				
				# Build the base url
				(my $url = $hash->{File}) =~ s{.*PDL/}{};
				$url =~ s{\.[^./]+}{};
				$url = "http://pdl.sourceforge.net/PDLdocs/$url.html";
				
				# Identify the module
				my $module = $hash->{Module};
				
				# Handle full-module references vs single functions
				if (not defined $module) {
					($module = $hash->{File}) =~ s{.*PDL/}{PDL::};
					$module =~ s{/}{::}g;
				}
				else {
					$url .= "#$command";
				}
				push @modules, "$module ($url)";
			}
			$where_is .= join ', ', @modules;
			say_it("$nick: $where_is");
		}
		else {
			say_it("$nick: Could not find $command.");
		}
	}
	elsif ($msg =~ /^liddle_piddle_bot[,:]? tell (\w+) (.*)/) {
		my ($nick_to_tell, $message) = ($1, $2);
		$messages{$nick_to_tell} .= '; ' if exists $messages{$nick_to_tell};
		$messages{$nick_to_tell} .= $message;
	}
}

sub do_private_response {
	my ($who, $message) = @_[ARG0, ARG2];
	my $nick = (split /!/, $who)[0];
	
	private_message($nick, "https://github.com/PDLPorters/pdl/wiki/PDL-IRC");
}

sub do_join {
	my ($who, $channel) = @_[ARG0, ARG1];
	my $nick = (split /!/, $who)[0];

	# Make an op if they're recognized:
	if ($ops{$nick}) {
		$irc->yield(mode => '#pdl +o', $nick);
	}
	
	# Send delayed messages to users
	while (my ($nick_to_tell, $message) = each %messages) {
		if ($nick =~ /$nick_to_tell/) {
			say_it("$nick, $messages{$nick_to_tell}");
			delete $messages{$nick_to_tell};
		}
	}
}

1;
