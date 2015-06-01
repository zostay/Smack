unit class Spackle::Runner;

use Spackle::Handler;
use Spackle::Loader;

sub MAIN(
    Str  :a($app),
    Str  :o($host),
    Int  :p($port),
) is export(:MAIN) {
    my %options;
    %options<app>  = $app if $app;
    %options<host> = $host if $host;
    %options<port> = $port if $port;

    my $runner = Spackle::Runner.new(|%options);
    $runner.run;
}

has Str $.app = 'app.psgi';
has Str $.host = '0.0.0.0';
has Int $.port = 5000;
has Str $!loader-name = 'Basic';
has Spackle::Loader $!loader = self!build-loader;
has Str $!server-name;

has %.server-options = 
    host => $!host,
    port => $!port,
    ;

method !build-loader() returns Spackle::Loader {
    my $class = "Spackle::Loader::$!loader-name";
    require ::($class);
    ::($class).new;
}

method load-server($loader) returns Spackle::Handler {
    if $!server-name.defined {
        $loader.load-server($!server-name, %!server-options);
    }
    else {
        $loader.load-server(%!server-options);
    }
}

method run {
    my $server = self.load-server($!loader);
    my &app = $!app.IO.slurp.EVAL;
    $server.run(&app);
}

