use Smack::Test;

unit class Smack::Test::MockHTTP is Smack::Test;
use v6;

use HTTP::Request;
use HTTP::Message::P6WAPI;

multi method request(HTTP::Request $request, %config) {
    # The lack of mutators on URI is super annoying
    dd $request.uri.authority;
    $request.uri.scheme('http')    unless $request.uri.scheme;
    $request.uri.host('localhost') unless $request.uri.host;

    note "HOST = $request.uri.host()";

    my %env = request-to-p6wapi($request, :%config);

    my $p6w-res := self.run-app(%env, :%config);
    my $response = response-from-p6wapi($p6w-res);

    CATCH {
        default {
            return response-from-p6wapi(start {
                500,
                [ Content-Type => 'text/plain' ],
                [ .message ~ .backtrace ]
            });
        }
    }

    $response.request = $request;
    $response;
}
