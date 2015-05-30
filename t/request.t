#!perl6

use v6;

use Test;
use IO::String;
use Spackle::Request;

my $input = 'a+b=d&one+two+three+four=1234';

my $tmpfile = %*ENV<TMPDIR> 
    ~ '/' ~ $*USER ~ '.' ~ ([~] ('A'..'Z').roll(8)) ~ '.' ~ $*PID;
$tmpfile.IO.spurt($input);

END { unlink $tmpfile.IO }

my %env =
    REQUEST_METHOD      => 'GET',
    SCRIPT_NAME         => 'falcon.psgi',
    PATH_INFO           => '/one/two',
    REQUEST_URI         => '/app/one/two',
    QUERY_STRING        => 'a+b=c&(*+Pascal+*)=%2F*%20C%20*%2F;foo',
    SERVER_NAME         => 'www.example.com',
    SERVER_PORT         => '80',
    SERVER_PROTOCOL     => 'HTTP/1.1',
    CONTENT_LENGTH      => $input.encode.bytes,
    CONTENT_TYPE        => 'www/x-form-urlencoded; charset=UTF-8',
    HTTP_X_FOO          => 'Bar',
    HTTP_REFERER        => '/two/one',
    HTTP_HOST           => 'www.example.com',
    'psgi.version'      => [ 1, 1 ],
    'psgi.url_scheme'   => 'http',
    'psgi.input'        => $tmpfile.IO.open:r,
    'psgi.errors'       => $*ERR,
    'psgi.multithread'  => False,
    'psgi.multiprocess' => False,
    'psgi.run_once'     => True,
    'psgi.non_blocking' => False,
    'psgi.streaming'    => False,
;

my $req = Spackle::Request.new(%env);

is $req.protocol, 'HTTP/1.1', 'protocol is good';
is $req.method, 'GET', 'method is good';
is $req.port, 80, 'port is good';
is $req.request-uri, '/app/one/two', 'request-uri is good';
is $req.path-info, '/one/two', 'path-info is good';
is $req.path, '/one/two', 'path is good';
is $req.query-string, 'a+b=c&(*+Pascal+*)=%2F*%20C%20*%2F;foo', 'query-string is good';
is $req.script-name, 'falcon.psgi', 'script-name is good';
is $req.scheme, 'http', 'scheme is good';
is $req.secure, False, 'secure is good';
isa-ok $req.body, IO::Handle, 'body is good';
isa-ok $req.input, IO::Handle, 'input is good';

done;
