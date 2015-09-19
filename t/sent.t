#!perl6

use v6;

use Test;
use lib 't/lib';
use HTTP::Headers;
use Smack::Test;

my @tests =
    -> $c, $u {
        my $response;

        $response = $c.get($u);
        ok($response.success, 'successfully made a request');

        $response = $c.get($u);
        ok($response.success, 'successfully made a request');

        $response = $c.get($u);
        ok($response.success, 'successfully made a request');

        $response = $c.get("{$u}check");
        ok($response.success, 'successfully made a request');

        is $response.content, "3", "sent 3 times";
    };

my $test-server = Smack::Test.new(:app('sent-check.p6w'), :@tests);
$test-server.run;

done-testing;
