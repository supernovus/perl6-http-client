use v6;

class HTTP::Client;

has $.user-agent   is rw = 'perl6-HTTP::Client/1.0'; ## UserAgent
has $.http-version is rw = '1.1';                    ## The HTTP version.

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
method simple-request ($method, $url?, :%query) {
  if ($url) {
    my $req = self.make-request($method, $url, :%query);
    return $req.run;
  }
  self.make-request($method); ## Return an empty request, with no options.
}

## A request that requires data: POST, PUT
method data-request ($method, $url?, :%query, :%data, :%files, :$multipart) {
  if ($url) {
    my $req = self.make-request('POST', $url, :%query, :%data, :%files, :$multipart);
    return $req.run;
  }
  self.make-request('POST', :$multipart); ## Only multipart option is used.
}

## GET request
method get ($url?, :%query) {
  return self.simple-request('GET', $url, :%query);
}

## HEAD request
method head ($url?, :%query) {
  return self.simple-request('HEAD', $url, :%query);
}

## DELETE request
method delete ($url?, :%query) {
  return self.simple-request('DELETE', $url, :%query);
}

## POST request
method post ($url?, :%query, :%data, :%files, :$multipart) {
  return self.data-request('POST', $url, :%query, :%data, :%files, :$multipart);
}

## PUT request
method put ($url?, :%query, :%data, :%files, :$multipart) {
  return self.data-request('PUT', $url, :%query, :%data, :%files, :$multipart);
}

