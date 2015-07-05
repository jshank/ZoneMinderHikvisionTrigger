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
Draw the area you would like to enable motion detection for then click Stop Drawing
Set sensitivity to 60
Make sure Arming Schedule is set to all hours, all times (unless you want motion detection only during certain hours)
Save
=cut

use warnings;
use strict;
use Socket;
use ZoneMinder::Logger qw(:all);
use XML::Twig;
use LWP;
use YAML::XS 'LoadFile';

my $config = LoadFile('config.yaml');
# This is the URL that streams alerts such as motion detection. Documentation at http://goo.gl/S38ZQq
my $url = $config->{alertStreamUrl};
my $browser = LWP::UserAgent->new();
my $ipAddress;
my $lastEvent = "videoloss";
my $firstResponse = 1;
my $zm_trigger_ip = $config->{zm_trigger_ip};
my $zm_trigger_port = $config->{zm_trigger_port}; 
my $sql_auth = "-u".$config->{sql_credentials}->{username}." -p".$config->{sql_credentials}->{password};
my $secondsBeforeRecording = 3;
my $eventStartTime;
my @monitors = $config->{monitors};

# Create a Twig handler that will parse out the details of the event 
my $twig =
  new XML::Twig(
    twig_handlers => { EventNotificationAlert => \&AlertStreamHandler } );

# Create an LWP instance that will open a connection to the camera and
# read the alertStream in 1024 byte chunks and hand them to the raw_handler.
# This will automatically seperate the stream into parts per 
# http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4.2
#$browser->credentials($alertStreamHost.":".$alertStreamPort, '', $alertStreamUsername=>$alertStreamPassword);
my $response = $browser->get(
    #$alertStreamUrl,
    $url,
    ':content_cb'     => \&raw_handler,
    ':read_size_hint' => 1024,
);


=item raw_handler()

This handler takes the data read from the camera's alertStream and sends
the XML part along to the AlertStreamHandler via twig->parse

=cut

sub raw_handler {
    my ( $data, $response ) = @_;
	if ($firstResponse) {
		if ($response->is_success) {
		     print "Connected to camera\n";
			$firstResponse = 0;
		 }
		 else {
		     die $response->status_line;
		 }
	}
    # handle the payload and ignore the headers that start with --boundary
    unless ( $data =~ /^--boundary/ ) {
        $twig->parse($data);
    }
}

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
    unless ($eventType eq $lastEvent) {
        $lastEvent = $eventType;
	my $timeStamp = $eventAlert->first_child('dateTime')->text;
	if ($eventType eq "videoloss") {
		my $diff = time - $eventStartTime;
		print "Motion event ended after ".$diff." seconds\n";
		zm_trigger(9,"off");
	} 
	elsif ($eventType eq "VMD") {
		print "MOTION DETECTED at ".time."\n";
		$eventStartTime = time;
		zm_trigger(9,"on");
	}
    }
    #print "IP: " . $ip . "\n";
    #print "Event: " . $eventType . "\n";
    
}


=for comment{
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
		$sock->send($string_to_write);
		$sock->close();
		Info ("ARC:Sending string: $string_to_write. I'll wait for a while before I poll again");
	}

}
=for comment
  

	# 0 = motion not enabled, 1 = enabled but not detected, 2 = enabled and detected
	my ($motionvalue) = $contents =~ /<motionDetectAlarm>(.*)<\/motionDetectAlarm>/;

	if ($motionvalue eq "2")
	{
		#print "Motion detected for ".$iter->{name}."\n";
		Info( "ARC:Motion detected for $iter->{name}");
		if ($iter->{state} eq "off")
		{
	}

		else
		{
			Debug($iter->{name}." Already recording, not asking again\n");
		}
	}
	elsif ($motionvalue eq "1")
	{
		#print "Motion NOT detected for ".$iter->{name}."\n";
		if ($iter->{state} eq "on")
		{
	}
		else
		{
			#print $iter->{name}." is already stopped\n";
		}
	}
	else
	{
		Debug("Motion is NOT ENABLED for ".$iter->{name});
	}

=cut
