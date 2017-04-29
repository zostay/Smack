unit class Smack::Component;

use v6;

method configure(%config) { }

method call(%env) { }

# the to-app method is cached
has $!app;
method to-app() {
    my $self = self;
    return $!app if $!app;
    $!app = sub (%config) returns Callable {
        $self.configure(%config);
        sub (%env) { $self.call(%env) };
    }
}

# This only works correctly because to-app is cached
method wrap(&middleware) {
    self.to-app.wrap(&middleware);
}
