use v6;
use Smack::Component;

unit role Smack::Middleware is Smack::Component;

has &.app;

method configure(%env) {
   &!app = &.app.(%env) if &!app.returns ~~ Callable;
}

method call(%env) {
    &.app.(%env);
}

# This is sort of equivalent to Plack::Middleware::wrap.
method wrap-that(&app, *@_, *%_) {
    my $mw = self.new(:&app, |@_, |%_);
    $mw.to-app;
}
