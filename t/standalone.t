#!perl6

use v6;

use Test;
use HTTP::Client;
use HTTP::Headers;

constant $PORT = 47382;

for <app delayed streaming>.kv -> $i, $app {
    my $port = $PORT + $i;
    my $client = HTTP::Client.new;

    my $started = False;

    my $s = Proc::Async.new($*EXECUTABLE, '-Ilib', 't/server.pl6', "--port=$port", "--app=t/$app.psgi");
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

    my $response = $client.get("http://localhost:$port/");
    ok($response.success, 'successfully made a request');

    is($response.status, 200, 'returned 200');
    my $headers = HTTP::Headers.new: $response.headers;

    is $headers.elems, 1, 'only one header set';
    is $headers.Content-Type, 'text/plain', 'Content-Type: text/plain';

    is $response.content, 'Hello World', 'Content is Hello World';

    LEAVE {
        $s.kill(Signal::SIGQUIT);

        start {
            sleep 10;
            $s.kill(Signal::SIGKILL);
        };

        my $status = await $promise
            unless %*ENV<TEST_SMACK_SKIP_PROCESS_WAIT>;
        #is $status.exit, 0, 'exited ok';
    }
}

done;
