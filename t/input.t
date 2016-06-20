#!perl6

use v6;

use Test;
use lib 't/lib';
use Smack::Test;

my @tests =
    -> $c, $url {
        my $req = $c.post;
        $req.url($url);
        $req.add-header('Content-Type' => 'text/plain');
        $req.set-content('this is a test');
        my $response = $req.run;

        ok $response.success, 'request is ok';
        ok $response.content, 'this is a test';
    },
    ;

my $test-server = Smack::Test.new(:app<echo.p6w>, :@tests);
$test-server.run;

done-testing;
