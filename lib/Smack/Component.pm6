unit role Smack::Component;

use v6;

method configure(%env) { }

method call(%env) { }

# the to-app method should be is cached
has $!app;
method to-app() {
    return $!app if $!app;
    $!app = sub (%config --> Callable) {
        self.configure(%config);
        sub (%env) { self.call(%env) };
    }
}

# This only works correctly because to-app is cached
method wrap(&middleware) {
    self.to-app.wrap(&middleware);
}
