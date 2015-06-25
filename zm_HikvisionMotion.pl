#!/usr/bin/perl 

#---------------------------------------------------------------------------------------------
#
#  A trigger script that uses Foscam HD camera inbuilt motion detection
#  to start ZoneMinder recordings. When motion is detected, it records for 20seconds
#  (configurable).
#
#  Author: jshank
#  License: GPL
#
# More details:
# **** ONLY WORKS FOR HIKVISION CAMERAS.  ****
#
# Tested on: Ubuntu 14.04 running ZM 1.28.1
# Tested on: Hikvision XXXXXXX
#
# This is a script to use in conjunction with zoneminder trigger (zmtrigger.pl)
# This allows you to use Hikvision camera motion detector instead of ZM's software motion detector
# I've been benchmarking both, and in general, I've found Hikvisions own built in HW motion detector
# superior to ZM's software (either that, or ZM's motion sensor has too many variables to play with)
#
#
# So anyway, I found out how to capture motion detection status from this document:
# http://foscam.us/forum/cgi-sdk-for-hd-camera-t6045.html
#
# There are many more goodies in the document. 
#
#
# Summary: You need to set the Foscam HD camera to "enable Motion Detection", but don't enable
# recording in the camera, because you will be using ZM to record.
# Specifically, inside the camera:
# Alarm->Motion Detection: Enable, Sensitivity: High, Time Interval: 2s, UNCHECK Recording, Schedule: ALL
# Record->Alarm Recording: UNCHECK
# Record->Scheduled Recording: UNCHECK
#
# Please make sure your ZM monitor's are set to nodect for this script to initiate recordings
#


use LWP::Simple;
use Socket;
use XML::Parser::PerlSAX;
use MySAXHandler;
use ZoneMinder::Logger qw(:all);

$zm_trigger_ip = 'XX.XX.1.13'; #change this to the IP where ZM is running
$zm_trigger_port = 6802; # this is the default zm_trigger port
$sql_auth = ""; # change to "-uusername -ppassword" for your DB creds
$loop_dur = 3;

@monitors = (
	{
		name=>'Family Room', 		#descriptive name of your monitor. Only used for logging
		id=>10,				# zoneminder monitor id 	
		ip=>'XX.XX.1.129',		# IP of this camera
		port=>20003,			# port of this camera
		user=>'xxxxx',		# username auth
		password=>'xxxxx',		# password auth
		state=>'off',			# don't mess with this
		dur=>3,			# don't mess with this
		lasttime=>-1,			# dont mess with this
	},
	{
		name=>'Basement',
		id=>4,
		ip=>'XX.XX.1.125',
		port=>20001,
		user=>'xxxxx',
		password=>'xxxxx',
		state=>'off',
		dur=>3,
		lasttime=>-1,
	},
	{
		name=>'Garage',
		id=>9,
		ip=>'XX.XX.1.33',
		port=>20005,
		user=>'xxxxx',
		password=>'xxxxx',
		state=>'off',
		dur=>3,
		lasttime=>-1,
	},
	{
		name=>'Unfinished',
		id=>5,
		ip=>'XX.XX.1.17',
		port=>20000,
		user=>'xxxxx',
		password=>'xxxxx',
		state=>'off',
		dur=>3,
		lasttime=>-1,
	},
);


sub open_TCP
{
  # credit: http://www.oreilly.com/openbook/webclient/ch04.html
  # get parameters
  my ($FS, $dest, $port) = @_;
 
  #print "TCP:$dest $port\n";
  my $proto = getprotobyname('tcp');
  socket($FS, PF_INET, SOCK_STREAM, $proto);
  my $sin = sockaddr_in($port,inet_aton($dest));
  connect($FS,$sin) || return undef;
  
  my $old_fh = select($FS); 
  $| = 1; 		        # don't buffer output
  select($old_fh);
  1;
}

while (1)
{
for $iter (@monitors)
{
	#print "\n";
	#print $iter->{name},"\n";
	#print "=============================\n";
	if ($iter->{lasttime} != -1 )
	{
		# we are recording and counting down
		my $sec = time  - $iter->{lasttime};
		my $diff = $iter->{dur} - $sec;
		if ($diff >0 )
		{
			Debug("Waiting for $diff seconds before I poll this device...\n");
			next;
		}
		else
		{
			#print "I've waited all of ".$iter->{dur}." seconds for ".$iter->{name}.". Polling NOW\n";
			Info("ARC:I've waited all of ".$iter->{dur}." seconds for ".$iter->{name}.". Polling NOW");
			$iter->{lasttime} = -1;
			#$iter->{state} = 'off';
		}
	}

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

	
	# This is the URL that streams alerts such as motion detection. Documentation at http://goo.gl/S38ZQq
	my($url) = "http://"$iter->{user}.":"..$iter->{password}."@".$iter->{ip}.":".$iter->{port}."/ISAPI/Event/notification/alertStream";
        
       #start an instance of SAX parser for each monitor
	my $handler = SAXAlertStreamHandler->new();
	my $parser = XML::Parser::PerlSAX->new(Handler => $handler);
	
	my %parser_args = (Source => {SystemId => $url});
	$parser->parse(%parser_args);
	exit;
	
  );
  =for comment
  

	# 0 = motion not enabled, 1 = enabled but not detected, 2 = enabled and detected
	my ($motionvalue) = $contents =~ /<motionDetectAlarm>(.*)<\/motionDetectAlarm>/;

	if ($motionvalue eq "2")
	{
		#print "Motion detected for ".$iter->{name}."\n";
		Info( "ARC:Motion detected for $iter->{name}");
		if ($iter->{state} eq "off")
		{
			if (open_TCP(FD,$zm_trigger_ip,$zm_trigger_port) == undef)
			{
				#print "Error connecting to ZM_TRIGGER\n";
				Info ( "ARC:Error connecting to ZM_TRIGGER at $zm_trigger_ip:$zm_trigger_port");
				next;
			}
			else
			{
				#print "Success connecting to ZM_TRIGGER\n";
				$iter->{dur} = 20;
				my $string_to_write = $iter->{id}."|on+".$iter->{dur}."|1|External Motion|External Motion";
				#print "Sending $string_to_write\n";
				print FD $string_to_write;
				close FD;
				$iter->{state} = "on";
				$iter->{lasttime} = time;
				#printf "Recording started, doing it for 20s\n";
				Info ("ARC:Sending string: $string_to_write. I'll wait for a while before I poll again");
			}
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
			if (open_TCP(FD,$zm_trigger_ip,$zm_trigger_port) == undef)
			{
				#print "Error connecting to ZM_TRIGGER\n";
				Info ( "ARC:Error connecting to ZM_TRIGGER at $zm_trigger_ip:$zm_trigger_port");
				next;
			}
			else
			{
				#print "Success connecting to ZM_TRIGGER\n";
				my $string_to_write = $iter->{id}."|off|1|External Motion|External Motion";
				#print "Sending $string_to_write\n";
				print FD $string_to_write;
				close FD;

				Info( "ARC:Stopping video recording for $iter->{name}");
				$iter->{state} = "off";
				$iter->{dur} = 3;
			}
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
	
}
sleep $loop_dur;
} #while

=for comment
<EventNotificationAlert version="1.0" xmlns="http://www.hikvision.com/ver10/XMLSchema">
<ipAddress>10.1.10.23</ipAddress>
<portNo>80</portNo>
<protocol>HTTP</protocol>
<macAddress>c4:2f:90:27:19:e2</macAddress>
<channelID>1</channelID>
<dateTime>2015-06-24T19:37:22--8:00</dateTime>
<activePostCount>1</activePostCount>
<eventType>VMD</eventType>
<eventState>active</eventState>
<eventDescription>Motion alarm</eventDescription>
<DetectionRegionList>
</DetectionRegionList>
</EventNotificationAlert>
=cut
# begin the in-line package from http://www.xml.com/pub/a/2001/02/14/perlsax.html
package SAXAlertStreamHandler;
use strict;

my ($current_element, $vmdActive, $ipAddress);

sub new {
    my $type = shift;
    return bless {}, $type;
}

sub start_element {
    my ($self, $element) = @_;
	# We found an eventType element
    if ($element->{Name} eq 'eventType') {
        $current_element = 'event';
    }
    elsif ($element->{Name} eq 'ipAddress') {
        $current_element = 'ipAddress';
    }
}

sub characters {
    my ($self, $characters) = @_;
    my $text = $characters->{Data};
    if ($current_element eq 'event') {
       if ($text eq "VMD") {
        	#We found a video motion detection event
        	if ($vmdActive == 0) {
        		print "Motion event on ".$ipAddress." STARTED\n";
        	}
        	$vmdActive = 1;
        }
        elsif ($text eq 'videoloss') {
        	#Motion event has ended, we're back to videoloss SPAM
        	if ($vmdActive == 1) {
        		print "Motion event on ".$ipAddress." has ended\n";
        	}
        	$vmdActive = 0;
    }
    elseif ($current_element eq 'ipAddress') {
    	$ipAddress = $text;
    	}
    }
}

1; #Ye Olde 'Return True' for the in-line package...
