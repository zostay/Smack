use v6;

use Smack::Client::Message;

unit class Smack::Client::Response is Smack::Client::Message;

use HTTP::Status;

my subset StatusCode of UInt where 599 >= * >= 100;

has StatusCode $.code is rw is required;
has Str $.message is rw is required;

method is-success(Smack::Client::Response:D: --> Bool:D) { 299 >= $!code >= 200 }

method set-code(Smack::Client::Response:D: StatusCode $new-code --> Str:D) {
    my $new-message = get_http_status_msg($new-code);
    $!code    = $new-code;
    $!message = $new-message; # return the message set
}

method from-p6wapi(Smack::Client::Response:U: Int $code, @headers, Supply $body) {
    # This is how this information is provided from HTTP::Supply
    my $message = do with @headers.first(*.key eq '::server-reason-phrase') { .value } else { get_http_status_msg($code) };
    my $protocol = do with @headers.first(*.key eq '::server-protocol') { .value } else { 'HTTP/1.1' };

    my $self = self.bless(:$protocol, :$code, :$message, :$body);

    for @headers.map(*.kv).flat -> $field, $value {
        next if $field.starts-with(':');
        $self.header($field, :quiet) = $value;
    }

    $self;
}

method send($handle) {
    $handle.write: "$.protocol $.code $.message\r\n".encode('iso-8859-1');
    callsame;
}

multi method gist(Smack::Client::Response:D: --> Str:D) {
    return [~] "$.protocol $.code $.message\r\n", callsame;
}
