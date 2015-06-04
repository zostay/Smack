use Spackle::Loader;

unit class Spackle::Loader::Basic
does Spackle::Loader;

#| Does not do anything.
method watch(*@paths) { }

method guess { 
    return %!env<SPACKLE_SERVER> if %!env<SPACKLE_SERVER>;

    return 'Standalone';
}

multi method load-server(Str $server, %options) returns Spackle::Handler {
    my $class = "Spackle::Handler::$server";
    require ::($class);
    ::($class).new(|%options);
}

multi method load-server(%options) returns Spackle::Handler {
    my $guess = self.guess;
    return unless $guess;
    # callwith... ???
    self.load-server($guess, %options);
}
