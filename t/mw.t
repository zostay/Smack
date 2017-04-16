#!perl6

use v6;

use Test;
use lib 't/lib';
use Smack::Test;

my @tests =
    -> $c, $u {
        my $response = $c.get($u);
        ok $response.is-success, 'request is ok';

        is $response.header('P6W-Used'), 'True', 'mw inserted header';
    },
    ;

my $test-server = Smack::Test.new(:app<mw.p6w>, :@tests);
$test-server.run;
note $test-server.err;

done-testing;
