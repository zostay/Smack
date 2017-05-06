use Smack::Middleware;

unit class Smack::Middleware::Conditional is Smack::Middleware;
use v6;

has Mu $.condition is required;
has &!middleware;
has &.builder is required;

method configure(%config) {
    &!middleware = &.builder.(&.app);
    &!middleware.(%config) if &!middleware.returns ~~ Callable;
}

method call(%env) {
    my &app = %env ~~ $.condition ?? &!middleware !! &.app;
    return app(%env);
}
