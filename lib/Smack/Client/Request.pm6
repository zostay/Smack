use v6;

use Smack::Client::Message;

unit class Smack::Client::Request is Smack::Client::Message;

use Smack::URI;
use HTTP::Headers :standard-names;
use URI::Escape;

has Smack::URI $.uri is rw is required;
has Str $.method is rw is required;

method host(--> Str) { $!uri.host }
method port(--> UInt) { $!uri.port }
method relative-uri(--> Str) { $!uri.path-query // '/' }

method secure(--> Bool) { $!uri.scheme eq 'https' }

multi method to-wapi(Smack::Client::Request:D: --> Hash) {
    my sub _errors {
        my $errors = Supplier.new;
        $errors.Supply.tap: -> $s { $*ERR.say($s) };
        $errors;
    }

    my %config =
        'wapi.version'          => v0.9.Draft,
        'wapi.errors'           => _errors,
        'wapi.run-once'         => False,
        'wapi.multithread'      => False,
        'wapi.multiprocess'     => False,
        'wapi.protocol.support' => set('request-response'),
        'wapi.protocol.enabled' => set('request-response'),
        ;

    self.to-wapi(%config)
}

multi method to-wapi(Smack::Client::Request:D: %config --> Hash) {
    my %env = |%config,
        HTTP_HOST           => $.host,
        |$.headers.map({
            if .key eq 'content-length' {
                CONTENT_LENGTH => .value
            }
            elsif .key eq 'content-type' {
                CONTENT_TYPE => .value
            }
            else {
                'HTTP_' ~ .name.uc.trans('-' => '_') => .value
            }
        }),
        SERVER_PORT          => $.port,
        SERVER_NAME          => $.host,
        SCRIPT_NAME          => '',
        REQUEST_METHOD       => $.method,
        'wapi.url-scheme'    => $.uri.scheme,
        'wapi.body.encoding' => 'UTF-8',
        'wapi.protocol'      => 'request-response',
        PATH_INFO            => uri-unescape(~$.uri.path),
        QUERY_STRING         => ~$.uri.query // '',
        REQUEST_URI          => ~$.uri,
        ;

    %env;
}

method normalize(--> Nil) {
    $.headers.Host = $.host if !$.headers.Host && $.host;

    callsame;

    Nil;
}

method send(Smack::Client::Request:D: $handle --> Nil) {
    self.normalize;
    $handle.write: "$.method $.relative-uri $.protocol\r\n".encode("iso-8859-1");
    callsame;
}

multi method gist(Smack::Client::Request:D: --> Str:D) {
    self.normalize;
    return [~] "$.method $.relative-uri $.protocol\r\n", callsame;
}
