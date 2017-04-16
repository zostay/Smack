#!perl6

use v6;

use Test;
use lib 't/lib';
use Smack::Test;

my @tests =
    -> $c, $u {
        use HTTP::Request;
        my $req = HTTP::Request.new(POST => $u);
        $req.add-content("ok 1 # got some content\n");
        $req.add-content("1..1");
        my $response = $c.request($req);
        ok $response.is-success, 'request is ok';
    },
    ;

my $test-server = Smack::Test.new(:app<echo-err.p6w>, :@tests);
$test-server.run;

$test-server.treat-err-as-tap;

done-testing;
