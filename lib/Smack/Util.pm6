unit module Smack::Util;

use HTTP::Headers;

# TODO It would be super nice to cache request-headers and response-headers within a given %env, but we have to be wary of cache invalidation of @headers is modified.

sub request-headers(%env) is export {

    my sub setup-headers(%env) {
        my $h = HTTP::Headers.new;
        $h.Content-Type   = %env<CONTENT_TYPE>;
        $h.Content-Length = %env<CONTENT_LENGTH>;
        for %env.kv -> $name is copy, $value {
            $name.=subst(/^ 'HTTP_' /, '');
            $h{ $name } = $value;
        }

        $h
    }

    setup-headers(%env);
}

sub request-encoding(
    Str :$charset,
    :%env,
    Str:D :$fallback = 'ISO-8859-1',
) is export {

    $charset
        // request-headers(:%env).Content-Type.charset
        // $fallback
}

sub response-headers(
    $headers,
    :%env) is export {

    return $headers if $headers ~~ HTTP::Headers;

    HTTP::Headers.new($headers, :quiet)
}

sub response-encoding(
    Str :$charset,
    :$headers,
    :%env,
    Str:D :$fallback = 'UTF-8') is export {

    $charset
        // response-headers($headers, :%env).Content-Type.charset
        // (%env.defined && %env<p6sgi.body.encoding>)
        // $fallback
}

our sub header-remove(@h, $remove) {
    @h .= grep(*.key ne $remove)
}

our sub header-set(@h, *@headers, *%headers) {
    for flat @headers, %headers -> $p {
        my ($k, $v) = $p.kv;

        my @i = @h.grep({ .key eq $k }, :k);
        if @i {
            # Replace first header value with this
            my $i = shift @i;
            @h[$i] = $k => $v;

            # Delete the rest
            @h[ @i ] :delete;
            @h .= grep(Pair);
        }

        else {
            # No existing header value, add it
            push @h, $k => $v;
        }
    }
}

proto unpack-response(|) is export { * }

multi unpack-response(@res (Int() $status, @headers, Supply() $entity), &response-handler) {
    response-handler($status, @headers, $entity);
}

multi unpack-response(Promise:D $p, &response-handler) {
    my $res = await $p;
    unpack-response($res, &response-handler);
}

sub infix:<then-with-response> ($p, $c) is export {
    $p.then: -> $then {
        with unpack-response($then, $c) -> $r {
            when Supply {
                my ($s, $h) = |$then.result;
                $s, $h, $r
            }
            default { $r }
        }
        else {
            $then.result
        }
    }
}

multi stringify-encode(Blob $the-stuff,
    :%env, :$headers, Str :$charset) returns Blob is export {
    $the-stuff
}

multi stringify-encode(
    Str:D() $the-stuff,
    :%env,
    :$headers,
    Str :$charset,
) returns Blob is export {
    my $cs = response-encoding(:$charset, :%env, :$headers);
    $the-stuff.encode($cs);
}

multi stringify-encode(
    $the-stuff,
    :%env,
    :$headers,
    Str :$charset,
) returns Blob is export {
    my $cs = response-encoding(:$charset, :%env, :$headers);
    ''.encode($cs);
}

sub status-with-no-entity-body(Int(Any) $status) is export returns Bool:D {
    return $status < 200
        || $status == 204
        || $status == 304;
}

sub encode-html(Str() $str) returns Str is export {
    $str.trans(
        [ '&',     '>',    '<',    '"',      "'"     ] =>
        [ '&amp;', '&gt;', '&lt;', '&quot;', '&#39;' ]
    );
}

sub content-length(%env, Supply() $body) returns Supply is export {
    $body.grep(Blob | Str)
         .map({ stringify-encode($_, :%env).bytes })
         .reduce(&infix:<+>);
}
