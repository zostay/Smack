unit class Smack::Test;

use v6;

use HTTP::Client;
use HTTP::Headers;

constant $BASE-PORT = 46382;
my $port-iteration = 0;

has Bool $.quiet = %*ENV<TEST_SMACK_QUIET> // True;
has $.app is required;
has $.port = $BASE-PORT + $port-iteration++;
has $.skip-process-wait = %*ENV<TEST_SMACK_SKIP_PROCESS_WAIT>;
has @.tests;
has @.cmd = 'bin/smackup', '-a=t/apps/{app}', '-o=localhost', '-p={port}';

has $.err = '';
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
    $!server.stdout.tap(-> $v { $!started ||= $v ~~ /Starting/; self.diag($v) unless $!quiet });
    $!server.stderr.tap(-> $v { $!err ~= $v; self.diag($v) unless $!quiet });
    $!promise = $!server.start;
    my $wait-interval = Supply.interval(1);

    # Give it a second
    my $wait-count;
    react {
        whenever $wait-interval -> $n {
            done if $!started;
            die "server startup took too  long" if ($wait-count = $n) > 60;
        }

        whenever $!promise {
            die "server quit:\n\n$!err";
        }
    }
    sleep 1;
    self.diag("Server took {$wait-count+1} seconds(ish) to start.");
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

method treat-err-as-tap() {
    use Test;
    my $i = 0;
    for self.err.lines {
        $i++;
        # fake TAP
        when /^ \s* "not "? "ok $i" >> [ \s* "#" \s* $<msg> = [ .* ] ]/ { pass($/<msg>) }
        when /^ \s* "#" / { #`{ ignore comments } }
        when /^ \s* $/    { #`{ ignore blanks } }
        default { flunk($/<msg>) }
    }
}

method diag(*@msg) {
    my $msg = [~] @msg;
    note (("#" xx $msg.lines.elems) Z $msg.lines).join("\n");
}
