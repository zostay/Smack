#!perl6

use v6;

use Test;
use lib 't/lib';
use Smack::Test;

my @tests =
    -> $c, $u {
        my $response = $c.get($u);
        ok $response.is-success, 'request is ok';
    },
    ;

my $test-server = Smack::Test.new(:app<config-env.p6w>, :@tests);
$test-server.run;

$test-server.treat-err-as-tap;

done-testing;
