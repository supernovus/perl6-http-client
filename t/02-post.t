## To use this, you must have HTTP::Easy.
## Run the "examples/test.p6" on HTTP::Easy before running this.
## When connections to the outside world aren't so screwed up in Rakudo nom
## this will move to using proper sites again.

use v6;
BEGIN { @*INC.unshift: './lib'; }
use HTTP::Client;
use Test;

plan 5;

my $http = HTTP::Client.new;
#my $res = $htto.get('http://huri.net/test.txt');
my $req = $http.post;
$req.url('http://127.0.0.1:8080/test.txt');
$req.add-field(:name<Bob>);
my $res = $req.run;
#$*ERR.say: "~Status: "~$res.status;
#$*ERR.say: "~Message: "~$res.message;
#$*ERR.say: "~Proto: "~$res.protocol;
ok $res, "Constructed result object from direct get() call.";
ok $res.success, "Result was successful.";
my $content = $res.content;
#$*ERR.say: "~Content: $content";
#$*ERR.say: "~Headers: "~$res.headers.perl;
ok $content, "Content was returned.";
is $content, 'Hello World', "Content was correct.";
is $res.header('Content-Type'), 'text/plain', "Correct content type.";

