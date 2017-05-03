#!/usr/bin/env perl6
use v6;

use HTTP::Request::Common;
use HTTP::Status;
use Smack::Middleware::ConditionalGET;
use Smack::Test;
use Test;

my $tag  = "Foo";
my $date = "Wed, 23 Sep 2009 13:36:33 GMT";
my $non-matching-date = "Wed, 23 Sep 2009 13:36:32 GMT";

my @tests =
    {
        app     => ( 200, [ Content-Type => 'text/plain' ], [ 'OK' ] ),
        request => GET('/'),
        status  => 200,
        headers => [ Content-Type => 'text/plain' ],
    },
    {
        app     => ( 200, [ ETag => $tag, Content-Type => 'text/plain' ], [ 'OK' ] ),
        request => GET('/', If-None-Match => $tag),
        status  => 304,
        headers => [ ETag => $tag ],
    },
    {
        app     => ( 200, [ Last-Modified => $date, Content-Type => 'text/plain' ], [ 'OK' ] ),
        request => GET('/', If-Modified-Since => $date),
        status  => 304,
        headers => [ "Last-Modified" => $date ],
    },
    {
        app     => ( 200, [ Last-Modified => $date, Content-Type => 'text/plain' ], [ 'OK' ] ),
        request => GET('/', If-Modified-Since => $non-matching-date),
        status  => 200,
        headers => [
            Last-Modified => $date, Content-Type => "text/plain",
        ],
    },
    {
        app     => ( 200, [ Last-Modified => $date, Content-Type => 'text/plain' ], [ 'OK' ] ),
        request => GET('/', If-Modified-Since => "$date; length=2"),
        status  => 304,
        headers => [ "Last-Modified" => $date ],
    },
    {
        app     => ( 200, [ ETag => $tag, Content-Type => 'text/plain' ], [ 'OK' ] ),
        request => POST('/', content => '', If-None-Match => $tag),
        status  => 200,
        headers => [ ETag => $tag, 'Content-Type' => "text/plain" ],
    },
    {
        app     => ( 200, [ ETag => $tag, Last-Modified => $date, Content-Type => 'text/plain' ], [ 'OK' ] ),
        request => GET('/', If-None-Match => $tag, If-Modified-Since => $date),
        status  => 304,
        headers => [ ETag => $tag, 'Last-Modified' => $date ],
    },
    {
        app     => ( 200, [ ETag => $tag, Last-Modified => $date, Content-Type => 'text/plain' ], [ 'OK' ] ),
        request => GET('/', If-None-Match => 'Bar', If-Modified-Since => $date),
        status  => 200,
        headers => [ ETag => $tag, 'Last-Modified' => $date, 'Content-Type' => 'text/plain' ],
    },
    {
        app     => ( 200, [ ETag => $tag, Last-Modified => $date, Content-Type => 'text/plain' ], [ 'OK' ] ),
        request => GET('/', If-None-Match => $tag, If-Modified-since => $non-matching-date),
        status  => 200,
        headers => [ ETag => $tag,  'Last-Modified' => $date, 'Content-Type' => 'text/plain' ],
    },
    ;

for @tests -> %test {
    my $handler = Smack::Middleware::ConditionalGET.new(
        app => -> %env { start { %test<app> } }
    );

    test-p6wapi $handler, -> $c {
        my $res = $c.request(%test<request>);
        diag "ERROR: $res.decoded-content()" if is-error($res.code);
        is $res.code, %test<status>, "status matches expected %test<status>";
        for @(%test<headers>) {
            is $res.header.field(.key), .value, "header {.key} matches expected value";
        }
        if $res.code == 304 {
            is $res.decoded-content, '', '304 response has empty entity';
        }
    };
}

done-testing;
