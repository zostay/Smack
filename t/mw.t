#!perl6

use v6;

use Test;
use Smack::Test::Smackup;

my @tests =
    -> $c, $u {
        my $response = $c.get($u);
        ok $response.is-success, 'request is ok';

        is $response.header.field('P6W-Used'), 'True', 'mw inserted header';
    },
    ;

my $test-server = Smack::Test::Smackup.new(:app<mw.p6w>, :@tests);
$test-server.run;
note $test-server.err;

done-testing;
