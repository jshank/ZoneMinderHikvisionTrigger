package MultipartFilter;

use v5.12;
use warnings;

sub hookInto # $userAgent, onStart => sub { ... }, onDocument => sub { ... }, onEnd => sub { ... }
{
	my ($class,$ua,%args)=@_;
	my $onStart=$args{'onStart'}//sub {};
	my $onDocument=$args{'onDocument'}//sub {};
	my $onEnd=$args{'onEnd'}//sub {};
	$ua->add_handler(
		response_header => sub {
			# my ($response,$ua,$h)=@_;
			my ($response,$ua)=@_;
			$onStart->($response,$ua);
			# Remember how many times we called the onDocument callback
			$response->{'.multipartfilter'}=0;
			return;
		},
		m_media_type => "multipart/*"
	);
	my $flushDocuments=sub {
		my ($parts,$response,$ua)=@_;
			
		# get rid of all the parts that we have already processed
		for (my $i=0; $i<$response->{'.multipartfilter'}; $i++) {
			shift @$parts;
		}
		
		# call the onDocument callback for all new parts
		for my $part (@$parts) {
			$onDocument->($part,$response,$ua);
			$response->{'.multipartfilter'}++;
		}
	};
	$ua->add_handler(
		response_data => sub {
			# my ($response,$ua,$h,$data)=@_;
			my ($response,$ua)=@_;

			my @parts=$response->parts();
			# The last part is special, it may be not yet completely transmitted.
			# All other parts are complete, but may still need the onDocument 
			# callback call:
			my $lastpart=pop @parts;
			$flushDocuments->(\@parts,$response,$ua);
			
			my $clen=$lastpart->header('Content-Length');
			defined($clen) or die "Missing Content-Length header in multipart response";
			my $cref=$lastpart->content_ref(); # don't copy possibly large content around
			# If the content is shorter than announced, we have not yet
			# received all of it, and must not call the callback now.
			unless (length($$cref)<$clen) {
				$onDocument->($lastpart,$response,$ua); 
				$response->{'.multipartfilter'}++;
			}
			return 1;
		},
		m_media_type => "multipart/*"
	);
	$ua->add_handler(
		response_done => sub {
			# my ($response,$ua,$h)=@_;
			my ($response,$ua)=@_;
			
			my @parts=$response->parts();
			# All parts are complete, including the last one.
			# Make sure the callback has been called for all of them.
			$flushDocuments->(\@parts,$response,$ua);
			
			$onEnd->($response,$ua);
			return;
		},
		m_media_type => "multipart/*"
	);
	return;
}

1;
