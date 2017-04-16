#!perl6

use v6;

use Test;
use lib 't/lib';
use Smack::Test;

my @tests =
    -> $c, $url {
        my $req = $c.post($url, {}, Content-Type => 'text/plain');;
        $req.add-content('this is a test');
        my $response = $req.run;

        ok $response.is-success, 'request is ok';
        ok $response.content, 'this is a test';
    },
    ;

my $test-server = Smack::Test.new(:app<echo.p6w>, :@tests);
$test-server.run;

done-testing;
