use Smack::Middleware;

unit class Smack::Middleware::Conditional is Smack::Middleware;
use v6;

has &.condition is required;
has &!middleware;
has &.builder is required;

method configure(%config) {
    &!middleware = &.builder.(&.app);
    &!middleware.(%config) if &!middleware.returns ~~ Callable;
}

method call(%env) {
    my &app = &.condition.(%env) ?? &!middleware !! &.app;
    return app(%env);
}
