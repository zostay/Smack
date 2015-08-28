unit class Smack::Test;

use v6;

use HTTP::Client;
use HTTP::Headers;

constant $BASE-PORT = 46382;
my $port-iteration = 0;

has $.app is required;
has $.port = $BASE-PORT + $port-iteration++;
has $.skip-process-wait = %*ENV<TEST_SMACK_SKIP_PROCESS_WAIT>;
has @.tests;
has @.cmd = 'bin/smackup', '-a=t/apps/{app}', '-o=localhost', '-p={port}';

has $!started = False;
has $!client = HTTP::Client.new;
has $!server;
has $!promise;

method !resolve-cmd() {
    my %vars = :$.app, :$.port;
    .=subst(/'{' (<[ a .. z ]>+) '}'/, { %vars{$0} }, :g) for @!cmd;
}

method start() {
    self!resolve-cmd;
    $!server = Proc::Async.new($*EXECUTABLE, '-Ilib', |@.cmd);
    $!server.stdout.tap(-> $v { $!started ||= $v ~~ /Starting/; self.diag($v) });
    $!server.stderr.tap(-> $v { self.diag($v) });
    $!promise = $!server.start;

    # Give it a second
    my $wait-count = 0;
    until $!started {
        sleep 1;
        die "server startup took too long" if $wait-count++ > 60;
    }
    sleep 1;
    self.diag("Server took {$wait-count+1} seconds(ish) to start.");

    self.diag('server has started');
}

method run-tests() {
    for @.tests -> &test {
        test($!client, "http://localhost:$.port/");
    }
}

method stop() {
    $!server.kill(Signal::SIGQUIT);

    start {
        sleep 10;
        $!server.kill(Signal::SIGKILL);
    };

    my $status = await $!promise
        unless $.skip-process-wait;
    #is $status.exit, 0, 'exited ok';
}

method run() {
    self.start;
    self.run-tests;

    LEAVE {
        self.stop;
    }
}

method diag(*@msg) {
    my $msg = [~] @msg;
    note (("#" xx $msg.lines.elems) Z $msg.lines).join("\n");
}
