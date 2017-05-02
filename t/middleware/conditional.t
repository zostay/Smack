#!/usr/bin/env perl6
use v6;

use HTTP::Request::Common;
use Smack::Middleware::Conditional;
use Smack::Test;
use Smack::Util;
use Test;

sub wrapped-app(%env) {
    start {
        200,
        [ Content-Type => 'text/plain' ],
        [ 'Hello' ],
    }
}

my &app = Smack::Middleware::Conditional.new(
    app       => &wrapped-app,
    condition => { %^env<HTTP_X_ALLCAPS> eq 'YES-PLEASE' },
    builder   => -> &app {
        sub (%env) {
            app(%env).then(-> $p {
                unpack-response($p, -> $s, @h, $e {
                    $s, @h, $e.map(&uc)
                });
            });
        }
    },
).to-app;

test-p6wapi &app, -> $c {
    subtest {
        my $res = $c.request(GET '/', X-AllCaps => 'YES-PLEASE');
        is $res.decoded-content, 'HELLO', 'response is modified';
    }, 'condition active';

    subtest {
        my $res = $c.request(GET '/', X-AllCaps => 'no-thanks');
        is $res.decoded-content, 'Hello', 'response is original';
    }, 'condition inactive';
};

