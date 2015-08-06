unit role Smack::Loader;

use Smack::Handler;

has %.env is rw = %*ENV;
has &.app is rw;

method watch(*@paths) { ... }

# Seems to be broken or I don't understand it.
#multi method load-server(Str $server, %options) returns Smack::Handler { ... }
#multi method load-server(%options) returns Smack::Handler { ... }

method preload-app(&builder) {
    &!app = builder;
}

method run(Smack::Handler $server) {
    $server.run(&!app);
}
