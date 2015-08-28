#!perl6

use v6;

use Test;
use lib 't/lib';
use Smack::Test;

my @tests =
    -> $c, $u {
        my $response = $c.get($u);
        ok($response.success, 'successfully made a request');

        is($response.status, 200, 'returned 200');
        my $headers = HTTP::Headers.new: $response.headers;

        is $headers.elems, 1, 'only one header set';
        is $headers.Content-Type, 'text/plain', 'Content-Type: text/plain';

        is $response.content, 'Hello World', 'Content is Hello World';
    };

for <hello hello-promise hello-supply> -> $name {
    my $app = $name ~ ".p6w";
    my $test-server = Smack::Test.new(:$app, :@tests);
    $test-server.run;
}

done;
