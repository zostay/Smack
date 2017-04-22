use Smack::Test;

unit class Smack::Test::MockHTTP is Smack::Test;
use v6;

use HTTP::Request;
use HTTP::Message::P6WAPI;

multi method request(HTTP::Request $request, %config) {
    $request.uri.scheme //= 'http';
    $request.uri.host   //= 'localhost';

    my %env = request-to-p6wapi($request, :%config);

    my $response = response-from-p6wapi(self.run-app(%env, :%config));

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
