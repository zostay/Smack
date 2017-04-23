#!/usr/bin/env perl6
use v6;

use HTTP::Request::Common;
use Smack::App::File;
use Smack::Test;
use Test;

subtest {
    my $app = Smack::App::File.new(file => 'META.info'.IO);

    test-p6wapi $app, -> $c {
        my $response = $c.request(GET '/');
        ok $response.is-success, 'request is ok';

        is $response.code, 200, 'response status is 200';
        like $response.decoded-content, rx{Smack}, 'found expected content';

        diag $response.decoded-content unless $response.is-success;
    };

    test-p6wapi $app, -> $c {
        my $response = $c.request(GET "/whatever");
        ok $response.is-success, 'request is ok';

        is $response.media-type.type, 'text/plain', 'expected content type';
        is $response.code, 200, 'response status is still 200';
    };

}, 'serving a single file';

subtest {
    my $app = Smack::App::File.new(
        file         => 'META.info'.IO,
        content-type => 'application/json',
    );

    test-p6wapi $app, -> $c {
        my $response = $c.request(GET '/');
        is $response.code, 200, 'status is 200';
        like $response.decoded-content, rx{Smack}, 'found expected content';
    };

    test-p6wapi $app, -> $c {
        my $response = $c.request(GET '/whatever');
        is $response.media-type.type, 'application/json', 'expected content type';
        is $response.code, 200, 'status is 200';
    };

}, 'serving a single file with custom content=type';

subtest {
    my $app-secure = Smack::App::File.new(root => $*PROGRAM.parent);

    test-p6wapi $app-secure, -> $c {
        my $response = $c.request(GET '/file.t');
        is $response.code, 200, 'status is 200';
        like $response.decoded-content, rx:sigspace{We will find this literal string}, 'found literal string';
    };

    # test-p6wapi $app-secure, -> $c {
    #     my $response = $c.request(GET '/../app/file.t');
    #     is $response.code, 403, 'status is 403';
    #     is $response.decoded-content, 'Forbidden', 'content is Forbidden';
    # };

    test-p6wapi $app-secure, -> $c {
        for 1..100 -> $i {
            my $response = $c.request(GET '/file.t' ~ ("/" x $i));
            dd $response;
            is $response.code, 404, 'status is 404';
            is $response.decoded-content, 'Not Found', 'content is Not Found';
        }
    };
}, 'make sure root is secure';

done-testing;
