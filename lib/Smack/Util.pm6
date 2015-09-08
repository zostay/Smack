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
    %env,
    Str:D :$fallback = 'ISO-8859-1') is export {

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

sub stringify-encode($the-stuff,
    :%env,
    :$headers,
    Str :$charset) is export{

    my $cs = response-encoding(:$charset, :%env, :$headers)
    given $the-stuff {
        when Blob     { $the-stuff }
        when .defined { $the-stuff.Str.encode($cs) }
        default       { ''.encode($cs) }
    }
}

sub status-with-no-entity-body(Int(Any) $status) is export returns Bool:D {
    return $status < 200
        || $status == 204
        || $status == 304;
}
