unit class Smack::Middleware::Chunked
does Smack::Middleware;

use v6;

use HTTP::Headers;

method call(%env) {
    return &.app(%env) if %env<SERVER_PROTOCOL> eq 'HTTP/1.0';

    &.app.(%env).then(-> $p {
        my ($s, @headers, Supply(All) $body) = $p.result;

        my $h = HTTP::Headers.new(@headers, :quiet);
        return $p.result if $h<Content-Length> :exists || $h<Transfer-Encoding> :exists

        my $charset = $h.Content-Type.charset // %env<p6sgix.encoding>;

        my $CRLF = "\x0d\x0a".encode($charset);

        $h.Transfer-Encoding = 'chunked';
        $s, @headers, Supply.on-demand(-> $b {
            $body.tap(
                -> $chunk {
                    $chunk.=Str.=encode($charset)
                        unless $chunk ~~ Blob;

                    $b.emit(
                        [~] sprintf('%x', $chunk.bytes).encode($charset),
                            $CRLF, $chunk, $CRLF
                    ) if $chunk.bytes;
                },
                done => {
                    $b.emit("0\x0d\x0a\x0d\x0a");
                    $b.done;
                },
            );
            $body.wait;
        });
    });
}
