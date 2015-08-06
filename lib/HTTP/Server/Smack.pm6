unit class HTTP::Server::Smack;

use URI::Encode;
use DateTime::Format::RFC2822;
use HTTP::Headers;
use HTTP::Status;

has Str $.host;
has Int $.port;

has Bool $.debug = False;

has $!listener;

method run(&app) {
    self.setup-listener;
    self.accept-loop(&app);
}

method setup-listener {
    $!listener = IO::Socket::INET.new(
        localhost => $!host,
        localport => $!port,
        listen    => True,
    );
}


method accept-loop(&app) {
    while my $conn = $!listener.accept {

        my %env =
            SERVER_PORT            => $!port,
            SERVER_NAME            => $!host,
            SCRIPT_NAME            => '',
            REMOTE_ADDR            => $conn.local_address,
            'psgi.version'         => Version.new('0.1.Draft'),
            'psgi.errors'          => $*ERR,
            'psgi.url_scheme'      => 'http',
            'psgi.run_once'        => False,
            'psgi.multithread'     => True,
            'psgi.multiprocess'    => False,
            'psgi.streaming'       => True,
            'psgi.nonblocking'     => False,
            'psgi.input.buffered'  => True,
            'psgi.errors.buffered' => False,
            'psgi.encoding'        => 'UTF-8',
            ;

        #$*SCHEDULER.cue: {
            self.handle-connection(%env, $conn, &app);
            LEAVE {
                $conn.close;
            };
        #};
    }

    LEAVE {
        $!listener.close;
        $!listener = IO::Socket::INET;
    }
}

constant CR = 0x0d;
constant LF = 0x0a;

method !temp-file {
    ($*TMPDIR ~ '/' ~ $*USER ~ '.' ~ ([~] ('A' .. 'Z').roll(8)) ~ '.' ~ $*PID).IO
}

method handle-connection(%env, $conn, &app) {
    my $res = [ 400, [ 'Content-Type' => 'text/plain' ], [ 'Bad Request' ] ];

    note "[debug] Received connection..." if $!debug;

    my $header-end;
    my $checked-through = 3;
    my $whole-buf = Buf.new;

    while my $buf = $conn.recv(:bin) {
        $whole-buf = $whole-buf ~ $buf;

        CRLF: for $checked-through .. $whole-buf.end {
            next CRLF unless $whole-buf[$_-3] == CR;
            next CRLF unless $whole-buf[$_-2] == LF;
            next CRLF unless $whole-buf[$_-1] == CR;
            next CRLF unless $whole-buf[$_-0] == LF;

            $header-end = $_;
            last CRLF;
        }

        if $header-end {
            last;
        }
        else {
            $checked-through = $whole-buf.end - 2;
        }
    }

    # Header never ended!
    unless $header-end {
        note '[error] Header section does not end correctly';
        self.handle-response($res, $conn);
        return;
    }

    my $header = $buf.subbuf(0, $header-end).decode('ascii');
    $whole-buf = $buf.subbuf($header-end + 1);

    my @unfolded-headers = $header.split("\x0d\x0a");
    my $request-line = @unfolded-headers.shift;

    my @headers;
    for @unfolded-headers {
        when /^ \s/ {
            if @headers {
                @headers[*-1] ~= .subst(/^ \s+ /, ' ');
            }

            # Bad Request, malformed headers
            else {
                note '[error] Malformed headers in request';
                self.handle-response($res, $conn);
                return;
            }
        }

        default {
            @headers.push: $_;
        }
    }

    my $headers = HTTP::Headers.new;
    for @headers {
        my ($name, $value) = .split(/\s*:\s*/, 2);
        $headers.header($name, :quiet) = $value;
    }

    my $charset = $headers.Content-Type.charset // 'ISO-8859-1';
    my $length  = $headers.Content-Length.Int;

    $whole-buf = $conn.read($length - $whole-buf.elems)
        if $length - $whole-buf.elems > 0;

    my $content = $whole-buf.decode($charset);
    my $tmp = self!temp-file;
    $tmp.spurt($content);
    %env<psgi.input> = $tmp.open(:r);
    unlink $tmp;

    my ($method, $uri, $proto) = $request-line.split(" ", 3);

    %env<REQUEST_METHOD>  = $method;
    %env<REQUEST_URI>     = $uri;
    %env<SERVER_PROTOCOL> = $proto;

    my ($path, $query-string) = $uri.split('?', 2);
    %env<PATH_INFO>       = uri_decode($path);
    %env<QUERY_STRING>    = $query-string;

    %env<CONTENT_LENGTH>  = $length;
    %env<CONTENT_TYPE>    = ~$headers.Content-Type;

    for $headers.list -> $header {
        my $env-name = "HTTP_" ~ $header.name.uc.trans("-" => "_");
        %env{$header} = $header.value;
    }

    $res = app(%env);
    self.handle-response($res, $conn);
}

multi method handle-response(Promise $promised-res, $conn) {
    my $res = await $promised-res;
    self.handle-response($res, $conn);
}

multi method handle-response(Positional $res, $conn) {
    my $status-msg = get_http_status_msg($res[0]);

    # Header SHOULD be ASCII, but we'll treat it as UTF-8 just to be flexible
    # and avoid errors on our end.
    $conn.write("HTTP/1.0 $res[0] $status-msg\x0d\x0a".encode);
    $conn.write("{.key}: {.value}\x0d\x0a".encode) for @($res[1]);
    $conn.write("\x0d\x0a".encode);

    # Detect encoding
    my $ct = $res[1].first(*.key.lc eq 'content-type');
    my $charset = $ct.value.comb(/<-[;]>/)».trim.first(*.starts-with("charset="));
    $charset.=substr(8) if $charset;
    $charset //= 'UTF-8';

    given $res[2] {
        when Positional {
            for @($_) {
                $_ = $_.encode($charset) if $_ ~~ Str;
                $conn.write($_);
            }
            $conn.close;
        }

        when Channel {
            loop {
                my $v = .receive;
                $v = $v.encode($charset) if $v ~~ Str;
                $conn.write($v) if $v.elems;
            }

            CATCH {
                when X::Channel::ReceiveOnClosed {
                    $conn.close;
                }
            }
        }

        # Needs to be smarter
        default {
            die "Unknown body type. Unable to write response.";
        }
    }
}
