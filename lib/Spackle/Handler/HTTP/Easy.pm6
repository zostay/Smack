use Spackle::Handler;

unit class Spackle::Handler::HTTP::Easy
does Spackle::Handler;

use HTTP::Easy::PSGI;

has $.http = HTTP::Easy::PSGI.new(
    host => $!host,
    port => $!port,
);

method run(&app) { 
    say "Starting on http://$!host:$!port/...";
    $!http.handle(&app) 
}
