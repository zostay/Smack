use v6;

use Smack::Test;

unit class Smack::Test::MockHTTP is Smack::Test;

use Smack::Client::Request;
use Smack::Client::Response;

multi method request(Smack::Client::Request $request, %config) {
    start {
        # The lack of mutators on URI is super annoying
        $request.uri.scheme('http')    unless $request.uri.scheme;
        $request.uri.host('localhost') unless $request.uri.host;

        my %env = $request.to-wapi(:%config);

        my $wapi-res := self.run-app(%env, :%config);
        my Smack::Client::Response $response .= from-wapi($wapi-res);

        CATCH {
            default {
                .note;
                .rethrow;
                # return Smack::Client::Response.from-wapi(start {
                #     500,
                #     [ Content-Type => 'text/plain' ],
                #     [ .message ~ .backtrace ]
                # });
            }
        }

        $response.request = $request;
        $response;
    }
}
