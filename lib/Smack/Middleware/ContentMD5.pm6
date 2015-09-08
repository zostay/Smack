unit class Smack::Middleware::ContentMD5
does Smack::Middleware;

use Digest::MD5;

method call(%env) {
    &.app.(%env).then(-> $p {
        my ($s, @h, Supply(All) $body) = $p.result;

        my $headers = response-headers(:@headers, :%env);
        my $charset = response-encoding(:@headers, :%env);

        if !status-with-no-entity-body($s)
            && !$headers.Content-MD5
            && !$body.live {

            my @list;
            $body.tap: -> $v {
                push @list, my $buf = stringify-encode($v, :$headers, :%env);
            };
            $body.wait;

            push @h, Content-MD5 => Digest::MD5::md5_hex(@list);

            $s, @h, Supply.from-list(@list)
        }
    });
}
