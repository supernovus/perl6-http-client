use v6;

unit class HTTP::Client;

our $VERSION = '0.2'; ## The version of HTTP::Client.

## We offer a default user/agent.
has $.user-agent   is rw = "perl6-HTTP::Client/$VERSION"; # Perl6/$*PERL<version>";
has $.http-version is rw = '1.1'; ## Supported HTTP version.

## This is the main class. It handles the magic.

use HTTP::Client::Request;
use HTTP::Client::Response;

## Make a request object, and return it.
method make-request(Str $method, Str $url?, :%query, :%data, :@files, :$multipart) {
  my $request = HTTP::Client::Request.new(:$method, :client(self));
  if ($multipart) {
    $request.multipart;
  }
  if (@files) {
    $request.multipart; ## We need multipart for file uploads.
    for @files -> $filespec {
      if $filespec !~~ Hash { next; } ## Skip it.
      $request.add-file(|$filespec); ## Flatten it.
    }
  }
  if (%data) {
    $request.add-field(|%data);
  }
  if (%query) {
    $request.add-query(|%query);
  }
  if ($url) {
    $request.url($url);
  }
  return $request;
}

## A request that doesn't require data: GET, HEAD, DELETE
method simple-request ($method, $url?, :%query, :$follow) {
  if ($url) {
    my $req = self.make-request($method, $url, :%query);
    return self.do-request($req, :$follow);
  }
  self.make-request($method); ## Return an empty request, with no options.
}

## A request that requires data: POST, PUT
method data-request 
($method, $url?, :%query, :%data, :%files, :$multipart, :$follow) {
  if ($url) {
    my $req = self.make-request('POST', $url, :%query, :%data, :%files, :$multipart);
    return self.do-request($req, :$follow);
  }
  self.make-request('POST', :$multipart); ## Only multipart option is used.
}

## GET request
method get ($url?, :%query, :$follow) {
  return self.simple-request('GET', $url, :%query, :$follow);
}

## HEAD request
method head ($url?, :%query, :$follow) {
  return self.simple-request('HEAD', $url, :%query, :$follow);
}

## DELETE request
method delete ($url?, :%query, :$follow) {
  return self.simple-request('DELETE', $url, :%query, :$follow);
}

## POST request
method post ($url?, :%query, :%data, :%files, :$multipart, :$follow) {
  return self.data-request(
    'POST', $url, :%query, :%data, :%files, :$multipart, :$follow
  );
}

## PUT request
method put ($url?, :%query, :%data, :%files, :$multipart, :$follow) {
  return self.data-request(
    'PUT', $url, :%query, :%data, :%files, :$multipart, :$follow
  );
}

## Do the request
method do-request (HTTP::Client::Request $request, :$follow=0) {
  if ($request.protocol ne 'http') {
    die "Unsupported protocol, '{$request.protocol}'.";
  }

  my $host = $request.host;
  my $port = 80;
  if $request.port { $port = $request.port; }

#  $*ERR.say: "Connecting to '$host' on '$port'";

  my $sock = IO::Socket::INET.new(:$host, :$port);
  $sock.print(~$request);
  my $resp;
  my $chunk;
  repeat {
      $chunk = $sock.recv();
      $resp ~= $chunk;
  } while $chunk;
  $sock.close();

  my $response = HTTP::Client::Response.new($resp, self);
  if $follow && $response.redirect {
    my $newurl = $response.header('Location');
    if ! $newurl {
      die "Tried to follow a redirect that provided no URL.";
    }
    $request.url($newurl);
    return self.do-request($request, :follow($follow-1));
  }
  return $response;
}

