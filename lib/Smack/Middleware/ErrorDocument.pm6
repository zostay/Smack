unit class Smack::Middleware::ErrorDocument
does Smack::Middleware;

use v6;

use HTTP::Status;
use Smack::Util;

has Bool $.subrequest = False;
has %.error-documents[Int];

method call(%env) {
    $.app.(%env).then(-> $p {
        my (Int(Any) $s, @h, $b) = $p.result;
        return $p unless is-error($s) && %.error-documents{$s};

        my $path = %.error-documents{$s};
        if $.subrequest {
            for %env.kv -> $key, $value {
                unless $key ~~ /^p6sgi/ {
                    %env{'p6sgix.errordocument.' ~ $key} = $value;
                }
            }

            %env<REQUEST_METHOD> = 'GET';
            %env<REQUEST_URI>    = $path;
            %env<PATH_INFO>      = $path;
            %env<QUERY_STRING>   = '';
            %env<CONTENT_LENGTH> :delete;

            $.app.(%env).then(-> $sub-p {
                my (Int(Any) $sub-s, @sub-h, $sub-b) = $sub-p.result;

                if $sub-s == 200 {
                    $s, @sub-h, $sub-b;
                }

                $s, @h, $b;
            });
        }
        else {
            my $h = response-headers(@h);
            $h.Content-Length.remove;
            $h.Content-Encoding.remove;
            $h.Transfer-Encoding.remove;
            $h.Content-Type = Smack::MIME.mime-type($path);

            @h = $h.for-P6SGI;

            my $fh = open $path, :r;
            $s, @h, Supply.on-demand(-> $s {
                $s.emit($fh.read($.bytes-at-a-time))
                    until $fh.eof;
                $s.done;
            });
        }
    });
}
