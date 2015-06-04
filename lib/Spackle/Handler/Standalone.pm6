use Spackle::Handler;
 
unit class Spackle::Handler::Standalone
does Spackle::Handler;
 
use HTTP::Server::Spackle;
 
has $.http = HTTP::Server::Spackle.new(
    host => $!host,
    port => $!port,
);
 
method run(&app) { 
    say "Starting on http://$!host:$!port/...";
    $!http.run(&app);
}
