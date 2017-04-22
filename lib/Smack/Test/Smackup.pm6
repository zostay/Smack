unit class Smack::Test::Smackup;

use v6;

use HTTP::UserAgent;

# TODO Replace when IO has the ability to let IO assign the port and tell us
# which port was assigned.
constant $BASE-PORT = 46382;
my $port-iteration = 0;

has Bool $.quiet = ?%*ENV<TEST_SMACK_QUIET> // True;
has $.app is required;
has $.port = $BASE-PORT + $port-iteration++;
has $.skip-process-wait = %*ENV<TEST_SMACK_SKIP_PROCESS_WAIT>;
has @.tests;
has @.cmd = 'bin/smackup', '-a=t/apps/{app}', '-o=localhost', '-p={port}';

has $.err = '';
has $!started = False;
has $!client = HTTP::UserAgent.new;
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
            die "server startup took too long" if ($wait-count = $n) > 60;
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
    subtest {
        my $i = 1;
        my $plan = 0;

        for self.err.lines {
            # Parse expected "TAP"
            when /^
                \s*
                $<ok> = [ "not "? "ok" ]
                " $i" >>
                [ \s* "#" \s* $<msg> = [ .* ] ]
            / {
                if $<ok> eq 'ok' {
                    pass($<msg>);
                }
                else {
                    flunk($<msg>);
                }
                $i++;
            }

            # Parse unexpected "TAP"
            when /^
                \s*
                $<ok> = [ "not "? "ok" ] " "
                $<got> = [ \d+ ] >>
                [ \s* "#" \s* $<msg> = [ .* ] ]
            / {
                flunk("out of order TAP output from p6w.errors");
                diag("\texpected: ok $i\n\t     got: $<ok> $<got>");
                is $<ok>, 'ok', $<msg>;
                $i++;
            }

            # Parse "TAP" test plan
            when /^ "1.." $<end-test> = [ \d+ ] $/ {
                $plan = $<end-test>.Int;
            }

            when /^ \s* "#" / { #`{ ignore comments } }

            when /^ \s* $/    { #`{ ignore blanks } }

            # Warn on other stuff
            default {
                note qq[# Strange "TAP" output from p6w.errors: $_];
            }
        }

        if $plan {
            plan $plan;
        }
        else {
            flunk(qq[no plan in "TAP" from p6w.errors]);
        }
    }, 'treat-err-as-tap';
}

method diag(*@msg) {
    my $msg = [~] @msg;
    note (("#" xx $msg.lines.elems) Z $msg.lines).join("\n");
}
