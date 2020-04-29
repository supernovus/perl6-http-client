use v6;
use HTTP::Client;
use Test;

plan 6;

my $http = HTTP::Client.new;
my $res = $http.get('https://raku.org/');
#my $res = $http.get('http://127.0.0.1:8080/test.txt');
#$*ERR.say: "~Status: "~$res.status;
#$*ERR.say: "~Message: "~$res.message;
#$*ERR.say: "~Proto: "~$res.protocol;
ok $res, "Constructed result object from direct get() call.";
ok $res.success, "Result was successful.";
my $content = $res.content;
#$*ERR.say: "~Content: $content";
#$*ERR.say: "~Headers: "~$res.headers.perl;
ok $content, "Content was returned.";
ok $content ~~ /Perl/, "Content was correct.";
ok $content ~~ /\<\/html\>/, "Got entire content";
ok $res.header('Content-Type') ~~ /^text\/html/, "Correct content type.";

