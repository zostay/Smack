unit class Smack::Request;

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

    my @cookies = self.Cookie.Str.comb(/<-[ ; , ]>+/).grep(/'='/);
    my %cookies = @cookies.map(*.trim.split('=', 2)).map({ uri_decode($_) });
    return %cookies;
}

method query-parameters(Smack::Request:D: Str $s?) {
    unless %!env<smack.request.query>.defined {
        %!env<smack.request.query> := Hash::MultiValue.from-pairs(self!parse-query);
    }

    # Kinda dumb...
    if $s.defined {
        %!env<smack.request.query>($s);
    }
    else {
        %!env<smack.request.query>;
    }
}

method !parse-urlencoded-string($qs) {
    return [] unless $qs.defined;

    my @qs = do for $qs.comb(/<-[ & ; ]>+/) {
        when / '=' / {
            my ($key, $value) = .split(/ '=' /, 2).map({ uri_decode( .subst(/ '+' /, ' ', :g)) });
            ~$key => ~$value
        }
        default {
            uri_decode( .subst(/ '+' /, ' ', :g) ) => Str but True
        }
    }

    @qs;
}

method !parse-query {
    self!parse-urlencoded-string(%!env<QUERY_STRING>);
}

method raw-content returns Blob {
    my $fh     = self.input;
    my $length = self.Content-Length;

    if $fh.defined && $length.defined && $length.Int > 0 {
        { # WHY?
            LEAVE {
                $fh.seek(0) if %!env<psgix.input.buffered>;
            }

            $fh.read($length.Int);
        }
    }

    else {
        ''.encode
    }
}

method content {
    warn "decoding content with non-text Content-Type and no defined charset"
        unless self.Content-Type.is-text
            || self.Content-Type.primary eq 'application/x-www-form-urlencoded' # this OK too
            || self.Content-Type.charset.defined;

    # RFC 2616 says ISO-8859-1 is assumed when no charset is given
    my $encoding = self.Content-Type.charset // 'ISO-8859-1';

    self.raw-content.decode($encoding);
}

has HTTP::Headers $.headers handles <header Content-Length Content-Type> = self!build-headers;

method !build-headers {
    my $headers = HTTP::Headers.new;
    for %!env.kv -> $k, $v {
        next unless $k ~~ /^ [ HTTP | CONTENT ] /;
        my $name = $k.subst(/^ HTTPS? _ /, '');
        $headers.header($name, :quiet) = $v;
    }

    return $headers;
}

method body-parameters(Smack::Request:D: Str $s?) {
    unless %!env<smack.request.body> {
        warn "reading parameters from body, but Content-Type is not application/x-www-form-urlencoded"
            unless self.Content-Type.primary eq 'application/x-www-form-urlencoded';


        %!env<smack.request.body> = Hash::MultiValue.from-pairs(self!parse-urlencoded-string(self.content));
    }

    if $s.defined {
        %!env<smack.request.body>($s);
    }
    else {
        %!env<smack.request.body>;
    }
}

method parameters(Smack::Request:D: Str $s?) {
    unless %!env<smack.request.merged> {
        %!env<smack.request.merged> = Hash::MultiValue.from-pairs(
            self.query-parameters.all-pairs,
            self.body-parameters.all-pairs,
        )
    }

    if $s.defined {
        %!env<smack.request.merged>($s);
    }
    else {
        %!env<smack.request.merged>;
    }
}

method param(Smack::Request:D: Str $s?) {
    if $s.defined {
        self.parameters($s)
    }
    else {
        self.parameters
    }
}
