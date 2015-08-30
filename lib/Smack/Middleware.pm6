use Smack::Component;

unit role Smack::Middleware is Smack::Component;

use v6;

has $.app;

# This is sort of equivalent to Plack::Middleware::wrap.
method wrap-that(&app, *@_, *%_) {
    my $mw = self.new(:&app, |@_, |%_);
    $mw.to-app;
}
