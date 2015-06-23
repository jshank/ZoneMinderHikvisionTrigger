use XML::SAX;
  use MySAXHandler;
  
  my $parser = XML::SAX::ParserFactory->parser(
        Handler => MySAXHandler->new
  );
  
  $parser->parse_uri("foo.xml")
/ISAPI/Event/notification/alertStream
