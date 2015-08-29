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

        my Promise $sent .= new;
        my $vow = $sent.vow;

        my %env =
            SERVER_PORT             => $!port,
            SERVER_NAME             => $!host,
            SCRIPT_NAME             => '',
            REMOTE_ADDR             => $conn.local_address,
            'p6sgi.version'         => Version.new('0.3.Draft'),
            'p6sgi.errors'          => $*ERR,
            'p6sgi.url_scheme'      => 'http',
            'p6sgi.run_once'        => False,
            'p6sgi.multithread'     => True,
            'p6sgi.multiprocess'    => False,
            'p6sgi.streaming'       => True,
            'p6sgi.nonblocking'     => False,
            'p6sgi.input.buffered'  => True,
            'p6sgi.errors.buffered' => False,
            'p6sgi.encoding'        => 'UTF-8',
            'p6sgix.output.sent'    => $sent,
            ;

        #$*SCHEDULER.cue: {
            self.handle-connection(%env, $conn, $vow, &app);
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

method handle-connection(%env, $conn, $vow, &app) {
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

    my $header = $buf.subbuf(0, $header-end).decode('ISO-8859-1');
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
                self.handle-response($res, $conn, $vow);
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
    %env<p6sgi.input> = $tmp.open(:r);
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
    self.handle-response($res, $conn, $vow);
}

method send-header($status, @headers, $conn) returns Str:D {
    my $status-msg = get_http_status_msg($status);

    # Header SHOULD be ASCII or ISO-8859-1, in theory, right?
    $conn.write("HTTP/1.0 $status $status-msg\x0d\x0a".encode('ISO-8859-1'));
    $conn.write("{.key}: {.value}\x0d\x0a".encode('ISO-8859-1')) for @headers;
    $conn.write("\x0d\x0a".encode('ISO-8859-1'));

    # Detect encoding
    my $ct = @headers.first(*.key.lc eq 'content-type');
    my $charset = $ct.value.comb(/<-[;]>/)».trim.first(*.starts-with("charset="));
    $charset.=substr(8) if $charset;
    $charset //= 'UTF-8';
}

multi method handle-response(Promise $promised-res, $conn, $vow) {
    my $res = await $promised-res;
    self.handle-response($res, $conn, $vow);
}

multi method handle-response(@res, $conn, $vow) {
    my $charset = self.send-header(@res[0], @res[1], $conn);

    given @res[2] {
        when Supply {
            .tap(
                -> $v {
                    my Blob $buf = do given ($v) {
                        when Str { $v.encode($charset) }
                        when Blob { $v }
                        default {
                            warn "Application emitted unknown message.";
                            Nil;
                        }
                    }
                    $conn.write($buf) if $buf;
                },
                done => { $conn.close; $vow.keep(Any) },
                quit => {
                    my $x = $_;
                    $conn.close;
                    CATCH {
                        # this is stupid, IO::Socket needs better exceptions
                        when "Not connected!" {
                            # ignore it
                        }
                    }
                    $vow.break($x);
                },
            );

            # stop here until done so the connection doesn't close
            .wait;
        }

        when Positional {
            for @($_) {
                $_ = ~$_ unless $_ ~~ any(Blob, Str);
                .=encode($charset) if $_ ~~ Str;
                $conn.write($_);
            }
            $conn.close;
            $vow.keep(Any);
        }

        # Custom Extension provided by Smack
        when Channel {
            loop {
                my $v = .receive;
                $v = $v.encode($charset) if $v ~~ Str;
                $conn.write($v) if $v.elems;
            }

            CATCH {
                when X::Channel::ReceiveOnClosed {
                    $conn.close;
                    $vow.keep(Any);
                }
            }
        }

        # Needs to be smarter
        default {
            die "Unknown body type. Unable to write response.";
        }
    }
}

multi method handle-response(&res, $conn, $vow) {
    my Promise $waiter .= new;
    res(-> @res {
        if @res.elems == 3 {
            self.handle-response(@res, $conn, $vow);
        }
        elsif @res.elems == 2 {
            my $charset = self.send-header(@res[0], @res[1], $conn);

            class {
                multi method write(Str $s)  { $conn.write($s.encode($charset)) }
                multi method write(Blob $b) { $conn.write($b) }
                multi method close()        { $conn.close; $waiter.keep; $vow.keep(Any) }
            }.new;
        }
        else {
            die 'Wrong number of elements in application response.';
        }
    });

    # pause or the connection will be closed prematurely
    await $waiter;
}
