#!perl6

use v6;

use Test;
use lib 't/lib';
use HTTP::Headers;
use Smack::Test;

my @tests =
    -> $c, $u {
        my $response;

        # Run three times
        for ^3 {
            $response = $c.get($u);
            ok $response.is-success, 'successfully made a request';
            ok $response.content, 'Hello World';
        }

        # Verify that the server kept the done promise thrice
        $response = $c.get("{$u}check");
        ok($response.is-success, 'successfully made a request');
        is $response.content, "3", "sent 3 times";
    };

my $test-server = Smack::Test.new(:app('sent-check.p6w'), :@tests);
$test-server.run;

done-testing;
