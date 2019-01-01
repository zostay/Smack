use v6;

use Smack::Client::Message;

unit class Smack::Client::Request is Smack::Client::Message;

use Smack::URI;
use HTTP::Headers :standard-names;

has Smack::URI $.uri is rw is required;
has Str $.method is rw is required;

method host(--> Str) { $!uri.host }
method port(--> UInt) { $!uri.port }

method send(Smack::Client::Request:D: $handle --> Nil) {
    $.headers.Host = $.host if !$.headers.Host && $.host;

    $handle.write: "$.method $.uri $.protocol\r\n".encode("iso-8859-1");
    callsame;
}

multi method gist(Smack::Client::Request:D: --> Str:D) {
    return [~] "$.method $.uri $.protocol\r\n", callsame;
}
