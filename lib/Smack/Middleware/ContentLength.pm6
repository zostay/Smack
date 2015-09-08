unit class Smack::Middleware::ContentLength
does Smack::Middleware;

method call(%env) {
    &.app.(%env).then(-> $p {
        my ($s, @h, Supply(All) $body) = $p.result;

        my $headers = response-headers(:@headers, :%env);
        my $charset = response-encoding(:@headers, :%env);

        if !status-with-no-entity-body($s)
            && !$headers.Content-Length
            && !$headers.Transfer-Encoding
            && !$body.live {

            my @list;
            my $content-length = 0;
            $body.tap: -> $v {
                push @list, my $buf = stringify-encode($v, :$headers, :%env);
                $content-length += $buf.bytes;
            };
            $body.wait;

            $s, @h, Supply.from-list(@list)
        }
    });
}
