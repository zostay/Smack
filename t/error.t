#!perl6

use v6;

use Test;
use lib 't/lib';
use Smack::Test;

my @tests =
    -> $c, $u {
        my $req = $c.post;
        $req.url($u);
        $req.set-content('ok 1 # got some content');
        my $response = $req.run;
        ok $response.success, 'request is ok';
    },
    ;

my $test-server = Smack::Test.new(:app<echo-err.p6w>, :@tests);
$test-server.run;

$test-server.treat-err-as-tap;

done-testing;
