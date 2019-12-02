use v6;

use Smack::Handler;

unit class Smack::Handler::CGI
does Smack::Handler;

use HTTP::Status;

method run(&app) {
    my Promise $sent .= new;
    my $vow = $sent.vow;

    my %env = %*ENV,
        'wapi.version'         => Version.new('0.9.Draft'),
        'wapi.inputs'          => $*IN,
        'wapi.errors'          => $*ERR,
        'wapi.url-scheme'      => %*ENV<HTTPS>//'off' ~~ any('on', '1') ?? 'https' !! 'http',
        'wapi.run-once'        => True,
        'wapi.multithread'     => False,
        'wapi.multiprocess'    => True,
        'wapi.nonblocking'     => False,
        'wapi.input.buffered'  => False,
        'wapi.errors.buffered' => True,
        'wapi.encoding'        => 'UTF-8',
        'wapix.output.sent'    => $sent,
        ;

    %env<HTTP_CONTENT_TYPE>:delete;
    %env<HTTP_CONTENT_LENGTH>:delete;
    %env<HTTP_COOKIE> ||= %env<COOKIE>; # O'Reilly server bug

    if %env<PATH_INFO> :!exists {
        %env<PATH_INFO> = '';
    }

    if %env<SCRIPT_NAME>//'' eq '/' {
        %env<SCRIPT_NAME> = '';
        %env<PATH_INFO>   = '/' ~ %env<PATH_INFO>;
    }

    await app(%env).then(-> $p {
        my (Int(Any) $status, $headers, Supply(Any) $body) = $p.result;
        self.handle-response($status, $headers, $body, $vow);
    });
}

method handle-response(Int $status, @headers, Supply $body, $vow) {
    my $status-msg = get_http_status_msg($status);

    # Header SHOULD be ASCII or ISO-8859-1, in theory, right?
    $*OUT.write("Status: $status $status-msg\x0d\x0a".encode('ISO-8859-1'));
    $*OUT.write("{.key}: {.value}\x0d\x0a".encode('ISO-8859-1')) for @headers;
    $*OUT.write("\x0d\x0a".encode('ISO-8859-1'));
    $*OUT.flush;

    # Detect encoding
    my $ct = @headers.first(*.key.lc eq 'content-type');
    my $charset = $ct.value.comb(/<-[;]>/)».trim.first(*.starts-with("charset="));
    $charset.=substr(8) if $charset;
    $charset //= 'UTF-8';

    my $encoded = False;
    $body.tap(
        -> $v {
            my Blob $buf = do given ($v) {
                when Cool { $encoded = True; $v.Str.encode($charset) }
                when Blob { $v }
                default {
                    warn "Application emitted unknown message.";
                    Nil;
                }
            }
            $*OUT.write($buf) if $buf;
        },
        done => { $vow.keep(Any) },
        quit => {
            my $x = $_;
            CATCH {
                # this is stupid, IO::Socket needs better exceptions
                when "Not connected!" {
                    # ignore it
                }
            }
            $vow.break($x);
        },
    );

    # stop here until done so we can finish
    $body.wait;
    $*OUT.flush;
}
