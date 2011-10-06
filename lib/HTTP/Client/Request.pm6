use v6;

class HTTP::Client::Request;

## This is the request class. It represents a request to an HTTP server.

use MIME::Base64;

#### Private constants
constant MULTIPART  = 'multipart/form-data';
constant URLENCODED = 'application/x-www-form-urlencoded';
constant $CRLF      = "\x0D\x0A";

#### Immutable public members.
has $.method;                  ## The HTTP Method for the request.
has $.client;                  ## Our parent HTTP::Client object.

#### Private members.
has $!proto is rw;             ## The protocol we will be connecting to.
has $!host is rw;              ## The host we are going to connect to.
has $!port is rw;              ## The port we are going to connect to.
has $!path is rw;              ## The path we are going to get.
has $!user is rw;              ## Username, if needed, for Authentication.
has $!pass is rw;              ## Password, if needed, for Authentication.
has $!auth is rw;              ## Auth type, can be Basic or Digest.
has $!type is rw = URLENCODED; ## Default to urlencoded forms.
has $!query is rw = '';        ## Part to add after the URL.
has $!data is rw = '';         ## The data body for POST/PUT.
has @!headers;                 ## Extra headers in Pair format, for sending.
has $!boundary is rw;          ## A unique boundary, set on first use.

#### Grammars

## A grammar representing a URL, as per our usage anyway.
## This is temporary until the URI library is working under "nom"
## then we'll move to using that instead, as it is far more complete.
grammar URL {
  regex TOP {
    ^
      <proto>
      '://'
      [<auth>'@']?
      <host>
      [':'<port>]?
      <path>
    $
  }
  token proto { \w+ }
  token host  { [\w|'.'|'-']+ }
  token port  { \d+ }
  token user  { \w+ }               ## That's right, simplest usernames only.
  token pass  { [\w|'-'|'+'|'%']+ } ## Fairly simple passwords only too.
  token auth  { <user> ':' <pass> } ## This assumes Basic Auth.
  regex path  { .* }
}

#### Public Methods

## Encode a username and password into Base64 for Basic Auth.
method base64encode ($user, $pass) {
  my $mime    = MIME::Base64.new();
  my $encoded = $mime.encode_base64($user~':'~$pass);
  return $encoded;
}

## Parse a URL into host, port and path.
method url ($url) {
  my $match = URL.parse($url);
  if ($match) {
    $!proto = ~$match<proto>;
    $!host  = ~$match<host>;
    if ($match<port>) {
      my $port = ~$match<port>;
#      $*ERR.say: "port is "~$port.perl;
      $!port = +$port;
#      $*ERR.say: "Setting port to $!port";
    }
    if (~$match<path>) {
      $!path = ~$match<path>;
    }
    if ($match<auth>) {
      ## The only auth we support via URL is Basic.
      $!auth = 'Basic';
      $!user = $match<auth><user>;
      $!pass = $match<auth><pass>;
    }
  }
}

## Get the protocol
method protocol {
  return $!proto;
}

## Get the hostname
method host {
  return $!host;
}

## Get the custom port.
## If this is not set, the library requesting it should use
## whatever is the default port for the protocol.
method port {
  return $!port;
}

## Get the path. If this is not set, you should use '/' or whatever
## makes sense in your application.
method path {
  return $!path;
}

## Use multipart POST/PUT.
method multipart {
  $!type = MULTIPART;
}

## Use urlencoded POST/PUT.
method urlencoded {
  $!type = URLENCODED;
}

## Use some custom type. May be useful for some web services.
method set-type ($type) {
  $!type = $type;
}

## Build a query (query string, or urlencoded form data.)
method build-query ($query is rw, %queries) {
  for %queries.kv -> $name, $value {
    if $query {
      $query ~= '&';
    }
    my $val; ## Storage for the value, in case of array.
    if $value ~~ Array {
      $val = $value.join('&'~$name~'='); ## It looks evil, but it works.
    }
    else {
      $val = $value;
    }
    $query ~= "$name=$val";
  }
}

## Add query fields.
method add-query (*%queries) {
  self.build-query($!query, %queries);
}

## Generate something fairly random.
method !randomstr {
  my $num = time * 1000.rand.Int;
  for 1..6.rand.Int+2 {
    my $ran = 1000000.rand.Int;
    if ($ran % 2) == 0 {
      $num += $ran;
    }
    else {
      $num -= $ran;
    }
  }
  my $str = $num.base(36);
  if 2.rand.Int {
    $str.=lc;
  }
  return $str;
}

## Get the boundary (generate it if needed.)
method boundary {
  if $!boundary { return $!boundary; }
  $!boundary = (for 1..4 { self!randomstr }).join;
  return $!boundary;
}

## Add data fields.
method add-field (*%queries) {
  ## First off, this only works on POST and PUT.
  if $.method ne 'POST' | 'PUT' {
    return self.add-query(|%queries);
  }
  if $!type eq URLENCODED {
    self.build-query($!data, %queries);
  }
  elsif $!type eq MULTIPART {
    for %queries.kv -> $name, $value {
      if ($value ~~ Array) {
        for @($value) -> $subval {
          self.add-part($subval, :$name);
        }
      }
      else {
        self.add-part($value, :$name);
      }
    }
  }
}

## Make a multipart section.
method make-part (
  $boundary, $value, :$type, :$binary, :$disp='form-data', *%conf
) {
  my $part = "--$boundary$CRLF";
  $part ~= "Content-Disposition: $disp";
  for %conf.kv -> $key, $val {
    $part ~= "; $key=\"$val\"";
  }
  $part ~= $CRLF; ## End of disposition header.
  if $type {
    $part ~= "Content-Type: $type$CRLF";
  }
  if $binary {
    $part ~= "Content-Transfer-Encoding: binary$CRLF";
  }
  $part ~= $CRLF; ## End of headers.
  $part ~= $value ~ $CRLF;
  return $part;
}

## Add a multipart section to our data.
method add-part ($value, :$type, :$binary, :$disp='form-data', *%conf) {
  if $!type ne MULTIPART { return; } ## We only work on multipart.
  $!data ~= self.make-part($.boundary, $value, :$type, :$binary, :$disp, |%conf);
}

## Add a file upload
method add-file (:$name!, :$filename!, :$content!, :$type, :$binary) {
  self.add-part($content, :$type, :$binary, :$name, :$filename);
}

## Set the data directly (may be useful for some web services.)
method set-content ($content) {
  $!data = $content;
}

## Add an extra header
method add-header (Pair $pair) {
  @!headers.push: $pair;
}

## See if a given header exists
method has-header ($name) {
  for @!headers -> $header {
    if $header.key eq $name { return True; }
  }
  return False;
}

## The method that actually builds the Request
## that will be sent to the HTTP Server.
method Str {
  my $version = $.client.http-version;
  my $output = "$.method $!path HTTP/$version$CRLF";
  self.add-header('Connection'=>'close');
  if ! self.has-header('User-Agent') {
    my $useragent = $.client.user-agent;
    self.add-header('User-Agent'=>$useragent);
  }
  if $!port {
    self.add-header('Host'=>$!host~':'~$!port);
  }
  else {
    self.add-header('Host'=>$!host);
  }
  if ! self.has-header('Accept') {
    ## The following is a hideous workaround for a bug in vim
    ## which breaks the perl6 plugin. It is there for my editing sanity
    ## only, and does not affect the end result.
    my $star = '*';
    self.add-header('Accept'=>"$star/$star");
  }
  if $.method eq 'POST' | 'PUT' {
    self.add-header('Content-Type'=>$!type);
  }
  if $!auth {
    if $!auth eq 'Basic' { ## Only one we're supporting right now.
      my $authstring = self.base64encode($!user, $!pass);
      self.add-header('Authorization'=>"Basic $authstring");
    }
  }
  if $!data {
    if $!type eq MULTIPART { 
      ## End our default boundary.
      $!data ~= "--{$!boundary}--$CRLF";
    }
    my $length = $!data.bytes;
    self.add-header('Content-Length'=>$length);
  }
  ## Okay, add the headers.
  for @!headers -> $header {
    if $header.key eq 'Content-Type' | 'Content-Length' { next; }
    $output ~= "{$header.key}: {$header.value}$CRLF";
  }
  if $!data {
    $output ~= $CRLF;   ## Add a blank line, notifying the end of headers.
    $output ~= $!data;  ## Add the data.
  }
  return $output;
}

## Execute the request. This is actually just a convenience
## wrapper for do-request() in the HTTP::Client class.
method run (:$follow) {
  $.client.do-request(self, :$follow);
}

