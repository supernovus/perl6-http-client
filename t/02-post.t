use v6;
use HTTP::Client;
use Test;

plan 5;

my $http = HTTP::Client.new;
my $req = $http.post;
$req.url('http://eu.httpbin.org/post');
$req.add-field(:query<http-client>, :mode<dist>);
my $res = $req.run;
ok $res, "Constructed result object from direct get() call.";
ok $res.success, "Result was successful.";
my $content = $res.content;
say $content;
ok $content, "Content was returned.";
ok $content ~~ /"http-client"/, "Content was correct.";
ok $res.header('Content-Type') ~~ /^application\/json/, "Correct content type.";

