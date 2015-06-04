#!spackle

use v6;
sub app(%env) {
    return [ 200, [ Content-Type => 'text/plain' ], [ "Hello World" ] ];
}
