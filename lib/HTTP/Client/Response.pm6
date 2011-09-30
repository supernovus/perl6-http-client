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
has $.proto;         ## HTTP proto/version returned by server.

## Private members
has @!headers;       ## The server response headers. An Array of Pairs.
                     ## Use $response.headers() or $response.header()
                     ## to get the headers.
has @!content;       ## The body of the message from the server.
                     ## Use $response.contents() for the array, or
                     ## $response.content() for a string.

## We override new, and expect the response from the server
## to be passed in, as well as a copy of our HTTP::Client object.
method new ($server_response, $client) {
  my @content = $server_response.split(/\n/);
  my $status_line = @content.shift;
  my ($proto, $status, $message) = $status_line.split(/\s/);
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
  self.bless(*, :$client, :$status, :$message, :$proto, :@headers, :@content);
}

multi method headers () {
  return @!headers;
}

multi method headers ($wanted) {
  my @matched;
  for @!headers -> $header {
    if $header.key ~~ $wanted {
      @matched.push: $header;
    }
  }
  return @matched;
}

method header ($wanted) {
  for @!headers -> $header {
    if $header.key ~~ $wanted {
      return $header;
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
      $length--;              # <CR>
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
  return self.contents(:$dechunk).join("\n");
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

