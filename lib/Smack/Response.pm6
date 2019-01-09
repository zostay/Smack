unit class Smack::Response;

use v6;

use HTTP::Headers;

class X::Smack::Response::MissingStatus is Exception {
    method message() { "missing status during finalize" }
}

has Int $.status;
has HTTP::Headers $.headers handles <header Content-Length Content-Type> = HTTP::Headers.new;
has @.body = [];

multi method redirect(Str $location, :$status = 302) {
    $!status = $status;
    self.headers.Location = $location;
}

multi method redirect() {
    self.headers.Location
}

method finalize() {
    die X::Smack::Response::MissingStatus.new
        unless $!status.defined;

    my @headers = $!headers.for-P6WAPI;

    return [
        $!status,
        @headers.item,
        @!body.item
    ];
}

method to-app {
    my $self = self;
    sub { $self.finalize }
}
