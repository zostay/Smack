#!perl6

use v6;

use Test;
use HTTP::Client;
use HTTP::Headers;

constant $PORT = 47382;

{
    my $client = HTTP::Client.new;

    my $started = False;

    my $s = Proc::Async.new($*EXECUTABLE, '-Ilib', 't/server.pl6', "--port=$PORT");
    $s.stdout.tap(-> $v { $started++ if $v ~~ /Starting/; diag $v });
    $s.stderr.tap(-> $v { diag $v });
    my $promise = $s.start;

    # Give it a second
    my $wait-count = 0;
    until $started {
        sleep 1;
        die "server startup took too long" if $wait-count++ > 60;
    }
    sleep 1;
    diag "Server took {$wait-count+1} seconds(ish) to start.";

    ok($s.started, 'server has started');

    my $response = $client.get("http://localhost:$PORT/");
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
