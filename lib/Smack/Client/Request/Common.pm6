use v6;

unit module Smack::Client::Request::Common;

use Smack::Client::Request;
use Smack::URI;

# EXPERIMENTAL!

my sub add-headers($req, @headers, %headers) {
    for flat @headers.map(*.kv), %headers.kv -> $key, $value {
        $req.header($key) = $value;
    }
}

sub HEAD(Smack::URI:D() $uri, *@headers, *%headers) is export {
    my $req = Smack::Client::Request.new(:method<HEAD>, :$uri);

    add-headers($req, @headers, %headers);

    $req;
}

sub GET(Smack::URI:D() $uri, *@headers, *%headers) is export {
    my $req = Smack::Client::Request.new(:method<GET>, :$uri);

    $req.Content-Length = 0;

    add-headers($req, @headers, %headers);

    $req;
}

our sub request-type-with-data(Str:D $method, Smack::URI:D() $uri, :$content, *@headers, *%headers) {
    my $req = Smack::Client::Request.new(:$method, :$uri);

    add-headers($req, @headers, %headers);

    $req.body = do given $content {
        when Supplier { .Supply }
        when Supply { $content }
        when IO::Handle {
            $content.encoding: Nil;
            $content.Supply;
        }
        when Blob {
            supply {
                emit $_;
            }
        }
        default {
            my $enc = $req.Content-Type.charset // 'iso-8859-1';
            supply {
                emit "$_".encode($enc);
            }
        }
    }

    $req;
}

sub POST(|c) is export { request-type-with-data('POST', |c) }
sub PUT(|c) is export { request-type-with-data('PUT', |c) }
