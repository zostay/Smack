use v6;
use Smack::Component;

unit class Smack::Middleware is Smack::Component;

has &.app;

method configure(%config) {
   &!app = &.app.(%config) if &!app.returns ~~ Callable;
}

method call(%env) {
    &.app.(%env);
}

# This is sort of equivalent to Plack::Middleware::wrap.
method wrap-that(Smack::Middleware:U: &app, *@_, *%_) {
    my $mw = self.new(:&app, |@_, |%_);
    $mw.to-app;
}
