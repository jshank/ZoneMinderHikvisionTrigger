#!/usr/bin/perl 

=for comment
---------------------------------------------------------------------------------------------

A trigger script that uses Hikvision camera inbuilt motion detection
to start ZoneMinder recordings. When motion is detected, it records until motion stops.

Author: jshank
License: GPL

More details:
**** ONLY WORKS FOR HIKVISION CAMERAS.  ****

Tested on: Ubuntu 14.04 running ZM 1.28.1
Tested on: Hikvision DS-2CD2332-I

This is a script to use in conjunction with zoneminder trigger (zmtrigger.pl)
This allows you to use Hikvision camera motion detector instead of ZM's software motion detector

Summary: You need to set the Hikvision as follow:
Configuration -> Advanced Configuration:
	Basic Event:
		[X] Enable Motion Detection
Configuration -> Security
	User:
		Level: Operator
		Basic Permissions
			[X] Remote: Notify Surveillance Center / Trigger Alarm Output
Draw the area you would like to enable motion detection for then click Stop Drawing
Set sensitivity to 60
Make sure Arming Schedule is set to all hours, all times (unless you want motion detection only during certain hours)
Save
=cut

use warnings;
use strict;
use Socket; #For calling out to zm_trigger over tcp
use ZoneMinder::Logger qw(:all);
use XML::Twig; #Handles our XML from the camera
use LWP; #Talks to the camera over HTTP
use MultipartFilter; #Proper handling of multipart HTTP
use Data::Dumper; #Debugging and diagnostice **Not needed for runtime**
use Config::JSON; # For storing configuration in JSON
# Next 3 packages are for supporting multiple cameras at once.
use Coro;
use Coro::LWP;
use EV;

my $config = Config::JSON->new('config.json');

# Create a Twig handler that will parse out the details of the event 
my $twig =
  new XML::Twig(
    twig_handlers => { EventNotificationAlert => \&AlertStreamHandler } );

# Create an LWP instance that will open a connection to the camera and
# read the alertStream via MultipartFilter and hand off our XML to AlertStreamHandler
# This will automatically seperate the stream into parts per 
# http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4.2
#$browser->credentials($alertStreamHost.":".$alertStreamPort, '', $alertStreamUsername=>$alertStreamPassword);
foreach my $monitor ($config->get("monitors")) { 
	foreach my $monitorvalues ($monitor) {
		while(my($ipAddress, $details) = each $monitorvalues ) {
			#Key is now the ipAddress of each monitor, value is a hash of the attributes.
			StartMonitor($ipAddress, $details);
		 }
	}
};
EV::loop;



sub StartMonitor {
	my ( $monitorIp, $monitorDetails) = @_;
	my $alertStreamUrl = "http://".$monitorDetails->{ 'username' }.":".$monitorDetails->{ 'password' }."@".$monitorIp."/Event/notification/alertStream";
	return async {
	#print "Monitor IP: ".$monitorIp."\n";
		print "Starting monitor: ".$alertStreamUrl."\n";
		my $browser = LWP::UserAgent->new();
		MultipartFilter->hookInto(
			$browser,
			onDocument => sub {
				my $part=shift;
				$twig->parse($part->content());
			}
		);

		my $response = $browser->get($alertStreamUrl);
	};
};

=item AlertStreamHandler()
Extracts the fields we're looking for from the AlertStream XML chunk
The eventType field has two main items we're looking for:
videoloss = the heartbeat signal (tehcnially videoloss with an eventState of inactive)
VMD = video motion detected
=cut

sub AlertStreamHandler {
    my ( $twig, $eventAlert ) = @_;
    my $ip        = $eventAlert->first_child('ipAddress')->text;
    my $eventType = $eventAlert->first_child('eventType')->text;
    my $eventStartTime = 0;
    my $monitorConfig =  $config->get("monitors/".$ip);
    my $lastEvent = $monitorConfig->{ 'lastevent' };
    unless ($eventType eq $lastEvent) {
        $config->set("monitors/".$ip."/lastevent", $eventType);
	my $timeStamp = $eventAlert->first_child('dateTime')->text;
	if ($eventType eq "videoloss") {
		my $diff = time - $eventStartTime;
		#print "Motion event ended after ".$diff." seconds\n";
		zm_trigger($monitorConfig->{'monitorId'},"off");
	} 
	elsif ($eventType eq "VMD") {
		#print "MOTION DETECTED at ".time."\n";
		$eventStartTime = time;
		zm_trigger(9,"on");
	}
    }
    #print "IP: " . $ip . "\n";
    #print "Event: " . $eventType . "\n";
    
}


=for comment
Hanging on to this string for possible future use
	$is_nodect=`/usr/bin/mysql -D zm $sql_auth -s -N -e  \"SELECT CONCAT(Enabled,Function) FROM Monitors WHERE Id=$iter->{id};\"`;
	chomp($is_nodect);
	if ($is_nodect ne "1Nodect")
	{
		$iter->{dur} = 60;
		$iter->{lasttime} = time;
		Info("ARC:$iter->{name} is in $is_nodect skipping for $iter->{dur}...");
		next;
	}
	else
	{

		Debug("ARC:$iter->{name} is in $is_nodect...");
	}

=cut 	


sub zm_trigger {
	my ( $monitorId, $recordState ) = @_;
	my $zm_trigger_ip = $config->get("zm_trigger_ip");
	my $zm_trigger_port = $config->get("zm_trigger_port"); 
	my $sock = IO::Socket::INET->new(PeerAddr => $zm_trigger_ip,
				 	PeerPort => $zm_trigger_port,
					Proto    => 'tcp');

	unless ($sock) {
		#print "Error connecting to ZM_TRIGGER\n";
		Info ( "ARC:Error connecting to ZM_TRIGGER at $zm_trigger_ip:$zm_trigger_port");
	}
	else {
		print "Success connecting to ZM_TRIGGER\n";
		my $string_to_write = $monitorId."|".$recordState."|1|External Motion|External Motion";
		print "Sending $string_to_write\n";
		#$sock->send($string_to_write);
		#$sock->close();
		#Info ("ARC:Sending string: $string_to_write. I'll wait for a while before I poll again");
	}

}
