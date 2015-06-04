#!perl6

use v6;

use Test;
use HTTP::Client;
use HTTP::Headers;

{
    my $client = HTTP::Client.new;

    my $s = Proc::Async.new($*EXECUTABLE, '-Ilib', 't/server.pl6', '--port=47382');
    $s.stdout.tap(-> $v { diag $v });
    $s.stderr.tap(-> $v { diag $v });
    my $promise = $s.start;

    # Give it a second
    sleep 5;

    ok($s.started, 'server has started');

    my $response = $client.get('http://localhost:47382/');
    ok($response.success, 'successfully made a request');

    is($response.status, 200, 'returned 200');
    my $headers = HTTP::Headers.new: $response.headers;

    is $headers.elems, 1, 'only one header set';
    is $headers.Content-Type, 'text/plain', 'Content-Type: text/plain';

    is $response.content, 'Hello World', 'Content is Hello World';

    LEAVE {
        $s.kill('QUIT');

        my $status = await $promise;
        #is $status.exit, 0, 'exited ok';
    }
}

done;
