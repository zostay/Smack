unit class Smack::Middleware::Conditional
does Smack::Middleware;

use v6;

has &.condition;
has $.middleware;
has &.builder;

method prepare-app() {
    $.middleware = &.builder.(&.app);
}

method call(%env) {
    my &app = &.condition.(%env) ?? &.middleware !! &.app;
    return app(%env);
}
