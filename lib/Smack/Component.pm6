unit role Smack::Component is Callable;

use v6;

method prepare-app() { }

# the to-app method should be is cached
has $!app;
method to-app() {
    return $!app if $!app;
    self.prepare-app;
    $!app = sub (%env) { self.CALL-ME(%env) }
}

# This only works correctly because to-app is cached
method wrap(&middleware) {
    self.to-app.wrap(&middleware);
}
