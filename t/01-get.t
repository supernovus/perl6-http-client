use v6;
BEGIN { @*INC.unshift: './lib'; }
use HTTP::Client;
use Test;

plan 5;

my $http = HTTP::Client.new;
my $res = $http.get('http://huri.net/test.txt');
ok $res, "Constructed result object from direct get() call.";
ok $res.success, "Result was successful.";
my $content = $res.content;
ok $content, "Content was returned.";
is $content, 'Hello World', "Content was correct.";
is $res.header('Content-Type').value, 'text/plain', "Correct content type.";
