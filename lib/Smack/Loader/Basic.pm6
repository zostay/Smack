use Smack::Loader;

unit class Smack::Loader::Basic
does Smack::Loader;

#| Does not do anything.
method watch(*@paths) { }

method guess {
    return %!env<SMACK_SERVER> if %!env<SMACK_SERVER>;
    return 'CGI' if %!env<GATEWAY_INTERFACE>;
    'Standalone';
}

multi method load-server(Str $server, %options) returns Smack::Handler {
    my $class = "Smack::Handler::$server";
    require ::($class);
    ::($class).new(|%options);
}

multi method load-server(%options) returns Smack::Handler {
    my $guess = self.guess;
    return unless $guess;
    # callwith... ???
    self.load-server($guess, %options);
}
