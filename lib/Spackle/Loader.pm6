unit role Spackle::Loader;

use Spackle::Handler;

has %.env is rw = %*ENV;
has &.app is rw;

method watch(*@paths) { ... }

#multi method load-server(Str $server, %options) returns Spackle::Handler { ... }
#multi method load-server(%options) returns Spackle::Handler { ... }

method preload-app(&builder) {
    &!app = builder;
}

method run(Spackle::Handler $server) {
    $server.run(&!app);
}
