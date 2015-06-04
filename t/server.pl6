#!perl6

use HTTP::Server::Spackle;

sub MAIN(Int :$port) {
    my $server = HTTP::Server::Spackle.new(
        host => 'localhost',
        port => $port,
    );

    my $psgi = "t/app.psgi".IO.slurp;
    my &app  = $psgi.EVAL;

    say "Starting on http://localhost:$port/...";
    $server.run(&app);
}
