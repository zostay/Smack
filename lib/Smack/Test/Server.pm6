unit class Smack::Test::Server is Smack::Test;
use v6;

use HTTP::UserAgent;
use Smack::Loader;

# TODO Replace when IO has the ability to let IO assign the port and tell us
# which port was assigned.
constant $BASE-PORT = 47382;
my $port-iteration = 0;

has $.host = '127.0.0.1';
has $.port = $BASE-PORT + $port-iteration++;
has $.server;
has $.ua = HTTP::UserAgent.new;

submethod TWEAK() {
    $!server = Plack::Loader.auto(:$!port, :$!host);
}

method request($request) {
    $request.uri.scheme('http');
    $request.uri.host($.host);
    $request.uri.port($.port);

    return $.ua.request($request);
}