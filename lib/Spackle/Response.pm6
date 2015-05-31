unit class Spackle::Response;

use v6;

use HTTP::Headers;

class X::Spackle::Response::MissingStatus is Exception { 
    method message() { "missing status during finalize" }
}

has Int $.status;
has HTTP::Headers $.headers handles * = HTTP::Headers.new;
has @.body = [];

multi method redirect(Str $location, :$status = 302) {
    $!status = $status;
    self.Location = $location;
}

multi method redirect() {
    self.Location
}

method finalize() {
    die X::Spackle::Response::MissingStatus.new
        unless $!status.defined;

    my @headers = $!headers.for-PSGI;

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
