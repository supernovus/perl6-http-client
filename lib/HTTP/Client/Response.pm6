use v6;

class HTTP::Client::Response;

## This is the response class. It represents a response from an HTTP server.

use HTTP::Status;

## Private constants
constant $CRLF = "\x0D\x0A";

## Public members.
has $.client;        ## Our parent HTTP::Client object.
has $.status;        ## The HTTP status code (numeric only.)
has $.message;       ## The text HTTP status message.
has $.protocol;      ## HTTP proto/version returned by server.

## Private members
has @!headers;       ## The server response headers. An Array of Pairs.
                     ## Use $response.headers() or $response.header()
                     ## to get the headers.
has @!content;       ## The body of the message from the server.
                     ## Use $response.contents() for the array, or
                     ## $response.content() for a string.

## We override new, and expect the socket representing our connection
## to be passed in, as well as a copy of our HTTP::Client object.
multi method new ($socket, $client) {
  my @content = $server_response.split($CRLF);
  my $status_line = @content.shift;
  my ($protocol, $status, $message) = $status_line.split(/\s/);
  if ! $message {
    $message = get_http_status_msg($status);
  }
  my @headers;
  while @content {
    my $line = @content.shift;
    last if $line eq ''; ## End of headers.
    my ($name, $value) = $line.split(': ');
    my $header = $name => $value;
    @headers.push: $header;
  }
  self.new(:$client, :$status, :$message, :$protocol)!initialize(@headers, @content);
}

## Used by new() to set the private members on the newly created instance.
method !initialize ($headers, $content) {
  @!headers := @($headers);
  @!content := @($content);
  return self;
}

multi method headers () {
  return @!headers;
}

multi method headers ($wanted) {
  my @matched;
  my $raw = False;
  if $wanted ~~ Regex { $raw = True; }
  for @!headers -> $header {
    if $header.key ~~ $wanted {
      if $raw {
        @matched.push: $header;
      }
      else {
        @matched.push: $header.value;
      }
    }
  }
  return @matched;
}

method header ($wanted) {
  my $raw = False;
  if $wanted ~~ Regex { $raw = True; }
  for @!headers -> $header {
    if $header.key ~~ $wanted {
      if $raw {
        return $header;
      }
      else {
        return $header.value;
      }
    }
  }
  return; ## Sorry, we didn't find anything.
}

## de-chunking algorithm stolen shamelessly from LWP::Simple
method dechunk (@contents) {
  my $transfer = self.header('Transfer-Encoding');
  if ! $transfer || $transfer !~~ /:i chunked/ {
    ## dechunking only to be done if Transfer-Encoding says so.
    return @contents;
  }
  my $pos = 0;
  while @contents {
    ## Chunk start: length as hex word
    my $length = splice(@contents, $pos, 1);
      
    ## Chunk length is hex and could contain extensions.
    ## See RFC2616, 3.6.1  -- e.g.  '5f32; xxx=...'
    if $length ~~ /^ \w+ / {
      $length = :16($length);
    }
    else {
      last;
    }

    ## Continue reading for '$length' bytes
    while $length > 0 && @contents.exists($pos) {
      my $line = @contents[$pos];
      $length -= $line.bytes; #.bytes, not .chars
      #$length--;              # <CR> removed.
      $pos++;
    }

    ## Stop decoding when a zero is encountered, RFC2616 again.
    if $length == 0 {
      ## Truncate document here.
      splice(@contents, $pos);
      last;
    }
  }
  return @contents;
}

method contents (Bool :$dechunk=True) {
  if $dechunk {
    return self.dechunk(@!content);
  }
  return @!content;
}

method content (Bool :$dechunk=True) {
  return self.contents(:$dechunk).join($CRLF);
}

method success (:$loose) {
  if $loose {
    if $.status ~~ /^2/ {
      return True;
    }
  }
  else {
    if $.status ~~ /^200$/ {
      return True;
    }
  }
  return False;
}

method redirect (:$loose, :$url) {
  if $loose {
    if $.status ~~ /^3/ {
      if $url {
        return self.header('Location');
      }
      return True;
    }
  }
  else {
    if $.status ~~ /30 <[12]>/ {
      if $url {
        return self.header('Location');
      }
      return True;
    }
  }
  return False;
}

