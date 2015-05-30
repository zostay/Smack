unit class Spackle::Request;

use v6;

use Hash::MultiValue;
use HTTP::Headers;
use URI::Encode;

has %.env;

method new(%env) {
    return self.bless(:%env);
}

method address      is rw { %!env<REMOTE_ADDR> }
method remote-host  is rw { %!env<REMOTE_HOST> }
method protocol     is rw { %!env<SERVER_PROTOCOL> }
method method       is rw { %!env<REQUEST_METHOD> }
method port         is rw { %!env<SERVER_PORT>.Int }
method user         is rw { %!env<REMOTE_USER> }
method request-uri  is rw { %!env<REQUEST_URI> }
method path-info    is rw { %!env<PATH_INFO> }
method path               { %!env<PATH_INFO> // '/' }
method query-string is rw { %!env<QUERY_STRING> }
method script-name  is rw { %!env<SCRIPT_NAME> }
method scheme       is rw { %!env<psgi.url_scheme> }
method secure             { self.scheme eq 'https' }
method body         is rw { %!env<psgi.input> }
method input        is rw { %!env<psgi.input> }

method session         is rw { %!env<psgix.session> }
method session_options is rw { %!env<psgix.session.options> }
method logger          is rw { %!env<psgix.logger> }

method cookies returns Hash {
    return {} unless self.Cookie;

    my @cookies = self.Cookie.Str.comb(/<-[ ; , ]>/).grep(/'='/);
    my %cookies = @cookies.map(*.trim.split('=', 2)).map({ uri_decode($_) });
    return %cookies;
}

method query-parameters {
    unless %!env<spackle.request.query>.defined {
        %!env{'spackle.request.query'} := Hash::MultiValue.from-pairs(self!parse-query);
    }

    %!env<spackle.request.query>;
}

method !parse-urlencoded-string($qs) {
    return [] unless $qs.defined;

    my @qs = do for $qs.comb(/<-[ & ; ]>/) {
        when / '=' / {
            my ($key, $value) = .split(/ '=' /, 2).map({ uri_decode( .subst(/ '+' /, ' ')) });
            $key => $value
        }
        default {
            uri_decode( .subst(/ '+' /, ' ') ) => Str
        }
    }

    @qs;
}

method !parse-query {
    self!parse-urlencoded-string(%!env<QUERY_STRING>);
}

method raw-content returns Buf {
    my $fh     = self.input;
    my $length = self.Content-Length.Int;

    if $fh.defined && $length.defined {
        LEAVE {
            $fh.seek(0, 0) if %!env<psgix.input.buffered>;
        }

        $fh.read($length);
    }

    else {
        ''
    }
}

method content {
    warn "decoding content with non-text Content-Type and no defined charset"
        unless self.Content-Type.is-text 
            || self.Content-Type.primary eq 'form/x-www-urlencoded' # this OK too
            || self.Content-Type.charset.defined;

    # RFC 2616 says ISO-8859-1 is assumed when no charset is given
    my $encoding = self.Content-Type.charset // 'ISO-8859-1';

    self.raw-content.decode($encoding);
}

has HTTP::Headers $.headers handles * = self!build-headers;

method !build-headers {
    my $headers = HTTP::Headers.new;
    for %!env.grep(*.key ~~ rx:i/^ [ HTTP | CONTENT ] /).kv -> $k, $v {
        my $name = $k.subst(/^ HTTPS? _ /, '');
        $headers.header($name, :quiet) = $v;
    }

    return $headers;
}

method body-parameters {
    unless %!env<spackle.request.body> {
        warn "reading parameters from body, but Content-Type is not form/x-www-urlencoded"
            unless self.Content-Type.primary eq 'form/x-www-urlencoded';


        %!env<spackle.request.body> = Hash::MultiValue.from-pairs(self!parse-urlencoded-string(self.content));
    }

    %!env<spackle.request.body>;
}

method parameters {
    unless %!env<spackle.request.merged> {
        %!env<spackle.request.merged> = Hash::MultiValue.from-pairs(
            self.query-parameters.all-pairs,
            self.body-parameters.all-pairs,
        )
    }

    %!env<spackle.request.merged>;
}

method param { self.parameters }
