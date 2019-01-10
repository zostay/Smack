use v6;

unit class Smack::Middleware::ErrorDocument
does Smack::Middleware;

use HTTP::Status;
use Smack::Util;

has Bool $.subrequest = False;
has %.error-documents[Int];

method call(%env) {
    callsame() then-with-response -> $s, @h, $e {
        return unless is-error($s) && %.error-documents{$s};

        my $path = %.error-documents{$s};
        if $.subrequest {
            for %env.kv -> $key, $value {
                unless $key ~~ /^p6w/ {
                    %env{"p6wx.errordocument.$key"} = $value;
                }
            }

            %env<REQUEST_METHOD> = 'GET';
            %env<REQUEST_URI>    = $path;
            %env<PATH_INFO>      = $path;
            %env<QUERY_STRING>   = '';
            %env<CONTENT_LENGTH> :delete;

            await callnext() then-with-response -> $sub-s, @sub-h, $sub-e {
                if $sub-s == 200 {
                    $s, @sub-h, $sub-e;
                }

                $s, @h, $e;
            }
        }
        else {
            header-remove(@h, 'Content-Length');
            header-remove(@h, 'Content-Encoding');
            header-remove(@h, 'Transfer-Encoding');
            header-set(@h, Smack::MIME.mime-type($path));

            open($path, :bin).Supply
        }
    });
}
