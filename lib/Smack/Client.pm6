use v6;

unit class Smack::Client;

use HTTP::Headers;
use HTTP::Supply::Response;
use Smack::Client::Request;
use Smack::Client::Response;

# EXPERIMENTAL!

has Int $.request-timeout = 30;

has Str $.enc = 'utf-8';

has Str $.user-agent = "Smack::Client/{::?PACKAGE.^ver//0}";

multi method request(Smack::Client::Request $req --> Promise:D) {
    start {
        $req.headers.User-Agent ||= $!user-agent;
        $req.headers.Connection ||= 'close';

        my $conn = await IO::Socket::Async.connect($req.host, $req.port, :$!enc);

        $conn.Supply.tap: { note "HERE" };

        LEAVE $conn.close;

        $req.send($conn);

        my $request-took-too-long = Promise.in($!request-timeout);

        my @res = await supply {
            whenever HTTP::Supply::Response.parse-http($conn.Supply(:bin), :!debug) -> $res {

                # Begin consuming the response body as quickly as we can and cache
                # it for reading by the caller.
                # my $body = Supplier::Preserving.new;
                # $res[2].tap: { $body.emit($_) }
                #     done => { $conn.close },
                #     quit => { $conn.close };

                emit [ $res[0], $res[1], $res[2] ];#$body.Supply ];
                done;
            }

            whenever $request-took-too-long {
                $conn.close;
                die "server took too long to response to request (more than $!request-timeout seconds)";
            }
        }

        Smack::Client::Response.from-p6wapi(|@res);
    }
}

multi method request(%env) {
    self.request(Smack::Client::Request.new(%env));
}

