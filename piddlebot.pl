#!/usr/bin/perl
# This is a simple IRC bot that just rot13 encrypts public messages.
# It responds to "rot13 <text to encrypt>".
use warnings;
use strict;
use POE;
use POE::Component::IRC::State;
use constant CHANNEL => '#pdl';

# Load the current piddlebot functions:
use piddlebot;
my $last_modified = (stat('piddlebot.pm'))[9];

# Create the component that will represent an IRC network.
our ($irc) = POE::Component::IRC::State->spawn();
our $my_nick = 'liddle_piddle_bot';

# Make sure the bot gets operator status
use POE::Component::IRC::Plugin::CycleEmpty;
$irc->plugin_add('CycleEmpty', POE::Component::IRC::Plugin::CycleEmpty->new());

# Create the bot session using methods in the main package, which are
# defined below. Note that irc_public, irc_message, and irc_join are just
# stubs that ensure the latest piddlebot.pm has been loaded, and then calls
# the latest do* response function. This way, I can make updates to the bot
# without having to restart it.
POE::Session->create(
	package_states => [
		main => [ qw(_start irc_001 irc_join irc_public irc_msg) ]
	]
);

# Run the bot!
$poe_kernel->run();



#!!!!!!!!!!!!!! No lexicals below this point !!!!!!!!!!!!!!#

# The bot session has started.  Register this bot with the "magnet"
# IRC component. Select a nickname. Connect to a server.
sub _start {
	$irc->yield(register => "all");
	$irc->yield(
		connect => {
			Nick     => $my_nick,
			Server   => 'irc.perl.org',
			Port     => '6667',
		}
	);
}

# A function that ensures that the latest piddlebot.pm is in use:
sub ensure_up_to_date {
	my $latest_modified = (stat('piddlebot.pm'))[9];
	do 'piddlebot.pm' if $last_modified < $latest_modified;
}

# The bot has successfully connected to a server.  Join a channel.
sub irc_001 {
	$irc->yield(join => CHANNEL);
}

############# Modifiable Callbacks #############

# The bot has received a public message. Reload the latest and 
sub irc_public {
	ensure_up_to_date;
	goto &do_public_response;
}

# The bot has received a public message.  Parse it for commands, and
# respond to interesting things.
sub irc_msg {
	ensure_up_to_date;
	goto &do_private_response;
}

sub irc_join {
	ensure_up_to_date;
	goto &do_join;
}

############# Response and Logging Functions #############

# Save the message to the logfile:
sub log_it {
	open my $logfile, '>>', 'pdl.log';
	my $ts = scalar localtime;

	print $logfile " [$ts] ", @_;
	print $logfile "\n" if (substr($_[-1], -1) ne "\n"); 
}

sub say_it {
	$irc->yield(privmsg => CHANNEL, join('', @_));
	log_it(@_);
}
