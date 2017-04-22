#!/usr/bin/env perl6
use v6;

use HTTP::Request::Common;
use Smack::App::File;
use Smack::Test;
use Test;

subtest {
    my $app = Smack::App::File.new(file => 'META.info'.IO).to-app;

    test-p6wapi :$app,
        client => -> $c {
            my $response = $c.request(GET '/');
            ok $response.is-success, 'request is ok';

            is $response.code, 200, 'response status is 200';
            like $response.decoded-content, rx{Smack}, 'found expected content';

            diag $response.decoded-content unless $response.is-success;
        },
        ;

    test-p6wapi :$app,
        client => -> $c {
            my $response = $c.request(GET "/whatever");
            ok $response.is-success, 'request is ok';

            is $response.media-type.type, 'text/plain', 'expected content type';
            is $response.code, 200, 'response status is still 200';
        },
        ;
}, 'serving a single file';

done-testing;
